package com.parental.screenmirror

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.Surface
import androidx.core.app.NotificationCompat

/**
 * Production Android Foreground Service that OWNS the active screen-mirroring lifecycle.
 *
 * Designed to survive Flutter Activity lifecycle changes:
 * - Flutter Activity backgrounded: Stream continues
 * - Flutter Activity destroyed/recreated: Stream continues
 * - Swiped away from Recents (onTaskRemoved): Foreground Service remains alive
 *
 * Compliant with Android 14/15:
 * - Uses FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
 * - Enforces one-time MediaProjection token rules
 * - Handles MediaProjection.Callback.onStop()
 * - Returns START_STICKY with REAUTHORIZATION_REQUIRED recovery
 */
class ScreenCaptureService : Service() {

    companion object {
        private const val TAG = "ScreenCaptureService"
        const val CHANNEL_ID = "screen_mirror_channel"
        const val NOTIFICATION_ID = 40401

        const val ACTION_START = "com.parental.screenmirror.ACTION_START"
        const val ACTION_STOP = "com.parental.screenmirror.ACTION_STOP"
        const val EXTRA_RESULT_CODE = "extra_result_code"
        const val EXTRA_RESULT_DATA = "extra_result_data"
        const val EXTRA_WIDTH = "extra_width"
        const val EXTRA_HEIGHT = "extra_height"
        const val EXTRA_DPI = "extra_dpi"
        const val EXTRA_SESSION_ID = "extra_session_id"

        var isRunning = false
            private set
    }

    private val binder = LocalBinder()
    private var mediaProjectionManager: MediaProjectionManager? = null
    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var surfaceCapturer: WebRTCSurfaceCapturer? = null

    private var currentWidth = 1280
    private var currentHeight = 720
    private var currentDpi = 320
    private var currentSessionId: String? = null

    inner class LocalBinder : Binder() {
        fun getService(): ScreenCaptureService = this@ScreenCaptureService
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "[FOREGROUND_SERVICE] ScreenCaptureService onCreate: Native service initializing")
        mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        createNotificationChannel()
        NativeCaptureManager.init(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        Log.i(TAG, "[FOREGROUND_SERVICE] onStartCommand received action: $action, flags: $flags")

        if (action == ACTION_STOP) {
            Log.i(TAG, "[FOREGROUND_SERVICE] Received STOP action request")
            NativeCaptureManager.transitionTo(NativeSessionState.STOPPING, "Stop action requested")
            stopCapture()
            stopSelf()
            return START_NOT_STICKY
        }

        if (action == ACTION_START) {
            val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, 0)
            val resultData = intent.getParcelableExtra<Intent>(EXTRA_RESULT_DATA)
            currentWidth = intent.getIntExtra(EXTRA_WIDTH, 1280)
            currentHeight = intent.getIntExtra(EXTRA_HEIGHT, 720)
            currentDpi = intent.getIntExtra(EXTRA_DPI, 320)
            currentSessionId = intent.getStringExtra(EXTRA_SESSION_ID)

            if (resultData != null && resultCode != 0) {
                NativeCaptureManager.transitionTo(NativeSessionState.STARTING, "Starting capture session")
                startForegroundWithNotification(NativeSessionState.CAPTURING)
                initMediaProjection(resultCode, resultData, currentWidth, currentHeight, currentDpi)
            } else {
                Log.e(TAG, "[MEDIA_PROJECTION] Missing resultCode or resultData in START intent")
                NativeCaptureManager.transitionTo(NativeSessionState.ERROR, "Missing MediaProjection result data")
                stopSelf()
            }
            return START_STICKY
        }

        // Handle Service Restart (START_STICKY after Android killed service for memory)
        if (intent == null) {
            Log.w(TAG, "[FOREGROUND_SERVICE] Service restarted by Android OS (intent is null)")
            // On modern Android (14+), MediaProjection token cannot be revived without fresh user authorization
            handleServiceRestartWithoutToken()
            return START_STICKY
        }

        return START_STICKY
    }

    private fun handleServiceRestartWithoutToken() {
        Log.w(TAG, "[MEDIA_PROJECTION] Android 14+ token cannot be recovered from memory restart. Setting state to REAUTHORIZATION_REQUIRED")
        NativeCaptureManager.transitionTo(NativeSessionState.REAUTHORIZATION_REQUIRED, "Process restarted without token")
        startForegroundWithNotification(NativeSessionState.REAUTHORIZATION_REQUIRED)
    }

    /**
     * CRITICAL LIFECYCLE HANDLER: SWIPE AWAY FROM RECENTS
     *
     * When the user swipes the Child app away from the Android Recents screen,
     * this callback fires.
     *
     * WE DO NOT CALL stopSelf() HERE if a screen mirroring session is active!
     * The Foreground Service continues running, capturing the screen and
     * maintaining the WebRTC stream to the Parent.
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.i(TAG, "[FOREGROUND_SERVICE] onTaskRemoved triggered: Child app swiped away from Recents")

        if (isRunning && mediaProjection != null) {
            Log.i(TAG, "[FOREGROUND_SERVICE] Active mirroring session in progress. MAINTAINING foreground service and WebRTC capture pipeline.")
            // Service continues running independently of Flutter Activity
        } else {
            Log.i(TAG, "[FOREGROUND_SERVICE] No active capture. Cleaning up service.")
            stopSelf()
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Screen Mirroring Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows an ongoing notification while remote screen sharing is active."
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun startForegroundWithNotification(state: NativeSessionState) {
        val stopIntent = Intent(this, ScreenCaptureService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            0,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val contentTitle = when (state) {
            NativeSessionState.REAUTHORIZATION_REQUIRED -> "Screen Mirroring Paused"
            NativeSessionState.RECONNECTING -> "Screen Mirroring: Reconnecting"
            else -> "Screen Mirroring Active"
        }

        val contentText = when (state) {
            NativeSessionState.REAUTHORIZATION_REQUIRED -> "Re-authorization required to resume screen sharing."
            NativeSessionState.RECONNECTING -> "Network switch detected. Restoring WebRTC connection..."
            else -> "Parent is currently viewing this device's screen"
        }

        val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(contentTitle)
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop Sharing", stopPendingIntent)

        val notification = notificationBuilder.build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        isRunning = true
        Log.i(TAG, "[FOREGROUND_SERVICE] Foreground notification pinned with type FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION")
    }

    private fun initMediaProjection(
        resultCode: Int,
        resultData: Intent,
        width: Int,
        height: Int,
        dpi: Int
    ) {
        try {
            Log.i(TAG, "[MEDIA_PROJECTION] Initializing MediaProjection token")
            mediaProjection = mediaProjectionManager?.getMediaProjection(resultCode, resultData)

            if (mediaProjection == null) {
                Log.e(TAG, "[MEDIA_PROJECTION] MediaProjectionManager returned null projection")
                NativeCaptureManager.transitionTo(NativeSessionState.ERROR, "MediaProjection token null")
                WebRTCBridge.notifyError("MEDIA_PROJECTION_NULL", "Failed to acquire MediaProjection instance")
                stopSelf()
                return
            }

            // System callback for user revocation or system termination
            mediaProjection?.registerCallback(object : MediaProjection.Callback() {
                override fun onStop() {
                    super.onStop()
                    Log.w(TAG, "[MEDIA_PROJECTION] System or user revoked MediaProjection via status chip")
                    NativeCaptureManager.transitionTo(NativeSessionState.REVOKED, "MediaProjection revoked by system")
                    stopCapture()
                    stopSelf()
                }
            }, null)

            NativeCaptureManager.transitionTo(NativeSessionState.CAPTURING, "MediaProjection initialized")

            // Connect to real WebRTC video surface sink
            val externalSurface = WebRTCBridge.getVideoInputSurface()
            if (externalSurface != null && externalSurface.isValid) {
                createVirtualDisplay(externalSurface, width, height, dpi)
                NativeCaptureManager.transitionTo(NativeSessionState.STREAMING, "VirtualDisplay created and streaming via bridge surface")
            } else {
                Log.i(TAG, "[MEDIA_PROJECTION] Creating native WebRTCSurfaceCapturer pipeline")
                surfaceCapturer = WebRTCSurfaceCapturer(mediaProjection!!, width, height, dpi)
                val surface = surfaceCapturer?.getSurface()
                if (surface != null && surface.isValid) {
                    createVirtualDisplay(surface, width, height, dpi)
                    NativeCaptureManager.transitionTo(NativeSessionState.STREAMING, "VirtualDisplay created via WebRTCSurfaceCapturer")
                } else {
                    Log.i(TAG, "[MEDIA_PROJECTION] WebRTC Surface pending; VirtualDisplay will attach once ready")
                }
            }

        } catch (e: SecurityException) {
            Log.e(TAG, "[MEDIA_PROJECTION] SecurityException: Foreground service not started before projection", e)
            NativeCaptureManager.transitionTo(NativeSessionState.ERROR, "SecurityException: ${e.message}")
            stopSelf()
        } catch (e: Exception) {
            Log.e(TAG, "[MEDIA_PROJECTION] Unexpected error initializing projection", e)
            NativeCaptureManager.transitionTo(NativeSessionState.ERROR, e.message ?: "Unknown error")
            stopSelf()
        }
    }

    fun attachSurface(surface: Surface, width: Int = currentWidth, height: Int = currentHeight, dpi: Int = currentDpi) {
        if (mediaProjection == null) {
            Log.e(TAG, "[MEDIA_PROJECTION] Cannot attach surface: MediaProjection is null")
            return
        }
        createVirtualDisplay(surface, width, height, dpi)
        NativeCaptureManager.transitionTo(NativeSessionState.STREAMING, "Surface attached to VirtualDisplay")
    }

    private fun createVirtualDisplay(surface: Surface, width: Int, height: Int, dpi: Int) {
        virtualDisplay?.release()
        Log.i(TAG, "[SCREEN_CAPTURE] Creating VirtualDisplay: ${width}x${height} @ ${dpi}dpi on Surface $surface")

        virtualDisplay = mediaProjection?.createVirtualDisplay(
            "ScreenMirrorDisplay",
            width,
            height,
            dpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            surface,
            null,
            null
        )
    }

    fun stopCapture() {
        Log.i(TAG, "[SCREEN_CAPTURE] Stopping capture and releasing native resources")
        try {
            surfaceCapturer?.dispose()
            surfaceCapturer = null

            virtualDisplay?.release()
            virtualDisplay = null

            mediaProjection?.stop()
            mediaProjection = null
        } catch (e: Exception) {
            Log.e(TAG, "[SCREEN_CAPTURE] Error during resource release", e)
        } finally {
            isRunning = false
            NativeCaptureManager.transitionTo(NativeSessionState.STOPPED, "Capture stopped cleanly")
        }
    }

    override fun onDestroy() {
        Log.i(TAG, "[FOREGROUND_SERVICE] ScreenCaptureService onDestroy called")
        stopCapture()
        super.onDestroy()
    }
}
