import { FileItem } from './types';

export const CODE_FILES: FileItem[] = [
  {
    name: 'NativeSessionState.kt',
    path: 'android/app/src/main/kotlin/com/parental/screenmirror/NativeSessionState.kt',
    language: 'kotlin',
    category: 'android',
    content: `package com.parental.screenmirror

/**
 * Native Android State Machine for the remote screen-mirroring lifecycle.
 *
 * Owned strictly by the native Android service layer and operates independently
 * of whether the Flutter Activity/UI is running, backgrounded, destroyed, or
 * removed from Recents.
 */
enum class NativeSessionState {
    IDLE,
    READY,
    STARTING,
    CAPTURING,
    CONNECTING,
    STREAMING,
    RECONNECTING,
    STOPPING,
    STOPPED,
    REVOKED,
    ERROR,
    REAUTHORIZATION_REQUIRED;

    fun toDisplayString(): String = when (this) {
        IDLE -> "Idle"
        READY -> "Ready for Request"
        STARTING -> "Starting Capture Service"
        CAPTURING -> "Screen Capture Active"
        CONNECTING -> "Connecting WebRTC"
        STREAMING -> "Streaming to Parent"
        RECONNECTING -> "Reconnecting Network (ICE Restart)"
        STOPPING -> "Stopping Session"
        STOPPED -> "Stopped"
        REVOKED -> "Revoked by User / System"
        ERROR -> "Error"
        REAUTHORIZATION_REQUIRED -> "Reauthorization Required (Android 14+ Token Expired)"
    }
}`
  },
  {
    name: 'ScreenCaptureService.kt',
    path: 'android/app/src/main/kotlin/com/parental/screenmirror/ScreenCaptureService.kt',
    language: 'kotlin',
    category: 'android',
    content: `package com.parental.screenmirror

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
 * - Swiped away from Recents (onTaskRemoved): Foreground Service remains alive!
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

        // Handle Service Restart (START_STICKY after OS killed service for RAM)
        if (intent == null) {
            Log.w(TAG, "[FOREGROUND_SERVICE] Service restarted by Android OS (intent is null)")
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
     * When user swipes Child app from Recents, this callback fires.
     * We DO NOT call stopSelf() if mirroring is active!
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.i(TAG, "[FOREGROUND_SERVICE] onTaskRemoved triggered: Child app swiped away from Recents")

        if (isRunning && mediaProjection != null) {
            Log.i(TAG, "[FOREGROUND_SERVICE] Active mirroring in progress. MAINTAINING foreground service and WebRTC capture.")
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
    }

    private fun initMediaProjection(
        resultCode: Int,
        resultData: Intent,
        width: Int,
        height: Int,
        dpi: Int
    ) {
        try {
            mediaProjection = mediaProjectionManager?.getMediaProjection(resultCode, resultData)

            if (mediaProjection == null) {
                NativeCaptureManager.transitionTo(NativeSessionState.ERROR, "MediaProjection token null")
                stopSelf()
                return
            }

            mediaProjection?.registerCallback(object : MediaProjection.Callback() {
                override fun onStop() {
                    super.onStop()
                    Log.w(TAG, "[MEDIA_PROJECTION] User/System revoked MediaProjection via status chip")
                    NativeCaptureManager.transitionTo(NativeSessionState.REVOKED, "MediaProjection revoked")
                    stopCapture()
                    stopSelf()
                }
            }, null)

            NativeCaptureManager.transitionTo(NativeSessionState.CAPTURING, "MediaProjection initialized")

            val surface = WebRTCBridge.getVideoInputSurface()
            if (surface != null && surface.isValid) {
                createVirtualDisplay(surface, width, height, dpi)
                NativeCaptureManager.transitionTo(NativeSessionState.STREAMING, "VirtualDisplay created and streaming")
            }
        } catch (e: Exception) {
            NativeCaptureManager.transitionTo(NativeSessionState.ERROR, e.message ?: "Unknown error")
            stopSelf()
        }
    }

    private fun createVirtualDisplay(surface: Surface, width: Int, height: Int, dpi: Int) {
        virtualDisplay?.release()
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
        try {
            virtualDisplay?.release()
            virtualDisplay = null
            mediaProjection?.stop()
            mediaProjection = null
        } finally {
            isRunning = false
            NativeCaptureManager.transitionTo(NativeSessionState.STOPPED, "Capture stopped cleanly")
        }
    }

    override fun onDestroy() {
        stopCapture()
        super.onDestroy()
    }
}`
  },
  {
    name: 'NativeCaptureManager.kt',
    path: 'android/app/src/main/kotlin/com/parental/screenmirror/NativeCaptureManager.kt',
    language: 'kotlin',
    category: 'android',
    content: `package com.parental.screenmirror

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.util.Log

/**
 * Central Native Manager for the screen capture lifecycle.
 *
 * Owns native state machine and network monitoring independently of Flutter.
 */
object NativeCaptureManager {

    private const val TAG = "NativeCaptureManager"
    private var applicationContext: Context? = null
    private var currentState: NativeSessionState = NativeSessionState.IDLE
    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    private val stateListeners = mutableListOf<(NativeSessionState) -> Unit>()

    fun init(context: Context) {
        this.applicationContext = context.applicationContext
        this.currentState = NativeStorageHelper.getNativeState(context)
        registerNetworkMonitoring(context.applicationContext)
    }

    fun getCurrentState(): NativeSessionState = currentState

    fun transitionTo(newState: NativeSessionState, reason: String = "") {
        if (currentState == newState) return
        Log.i(TAG, "[SESSION] State transition: $currentState -> $newState ($reason)")
        currentState = newState

        applicationContext?.let { ctx ->
            NativeStorageHelper.saveNativeState(ctx, newState)
        }

        stateListeners.forEach { it(newState) }
        WebRTCBridge.notifyStateChanged(newState.name)
    }

    private fun registerNetworkMonitoring(context: Context) {
        try {
            connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            val request = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()

            networkCallback = object : ConnectivityManager.NetworkCallback() {
                private var lastNetworkType: String = ""

                override fun onAvailable(network: Network) {
                    val caps = connectivityManager?.getNetworkCapabilities(network)
                    val currentType = when {
                        caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true -> "WIFI"
                        caps?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true -> "CELLULAR"
                        else -> "OTHER"
                    }

                    if (lastNetworkType.isNotEmpty() && lastNetworkType != currentType) {
                        Log.i(TAG, "[WEBRTC] Network handoff: $lastNetworkType -> $currentType. Initiating ICE restart.")
                        if (currentState == NativeSessionState.STREAMING || currentState == NativeSessionState.CAPTURING) {
                            transitionTo(NativeSessionState.RECONNECTING, "Network handoff")
                            WebRTCBridge.notifyNetworkChange(lastNetworkType, currentType)
                        }
                    }
                    lastNetworkType = currentType
                }

                override fun onLost(network: Network) {
                    if (currentState == NativeSessionState.STREAMING) {
                        transitionTo(NativeSessionState.RECONNECTING, "Network interface lost")
                    }
                }
            }

            networkCallback?.let {
                connectivityManager?.registerNetworkCallback(request, it)
            }
        } catch (e: Exception) {
            Log.w(TAG, "[WEBRTC] Failed to register network callback", e)
        }
    }
}`
  },
  {
    name: 'BootReceiver.kt',
    path: 'android/app/src/main/kotlin/com/parental/screenmirror/BootReceiver.kt',
    language: 'kotlin',
    category: 'android',
    content: `package com.parental.screenmirror

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Boot Receiver executed on device reboot.
 *
 * Restores pairing configuration and device presence state to READY.
 * Strictly NEVER bypasses user consent or pre-starts MediaProjection.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON"
        ) {
            if (!NativeStorageHelper.isConfigured(context)) return

            val deviceId = NativeStorageHelper.getDeviceId(context)
            val parentId = NativeStorageHelper.getPairedParentId(context)
            Log.i("BootReceiver", "[SESSION] Boot completed. Restored pairing: $deviceId -> $parentId")

            NativeCaptureManager.init(context)
            NativeCaptureManager.transitionTo(NativeSessionState.READY, "Restored after reboot")
        }
    }
}`
  },
  {
    name: 'NativeSignalingReceiver.kt',
    path: 'android/app/src/main/kotlin/com/parental/screenmirror/NativeSignalingReceiver.kt',
    language: 'kotlin',
    category: 'android',
    content: `package com.parental.screenmirror

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Native Broadcast / Push Receiver for session requests arriving from Parent
 * while the Child Flutter Activity is closed or in background.
 *
 * Displays a high-priority notification with a pending intent to trigger the
 * legitimate MediaProjection user consent prompt via MediaProjectionConsentActivity.
 */
class NativeSignalingReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_REMOTE_REQUEST = "com.parental.screenmirror.ACTION_REMOTE_REQUEST"
        const val CHANNEL_ID_REQUESTS = "screen_mirror_requests_channel"
        const val NOTIFICATION_ID_REQUEST = 40402
        const val EXTRA_SESSION_ID = "session_id"
        const val EXTRA_PARENT_ID = "parent_id"
        const val EXTRA_PARENT_NAME = "parent_name"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_REMOTE_REQUEST) {
            val sessionId = intent.getStringExtra(EXTRA_SESSION_ID) ?: ""
            val parentId = intent.getStringExtra(EXTRA_PARENT_ID) ?: ""
            val parentName = intent.getStringExtra(EXTRA_PARENT_NAME) ?: "Parent"

            val savedParentId = NativeStorageHelper.getPairedParentId(context)
            if (savedParentId == null || savedParentId != parentId) {
                Log.w("NativeSignalingReceiver", "[SECURITY] Rejected request from unlinked parent: $parentId")
                return
            }

            NativeStorageHelper.saveLastSessionId(context, sessionId)
            NativeCaptureManager.transitionTo(NativeSessionState.STARTING, "Incoming parent request")
            showConsentPromptNotification(context, sessionId, parentName)
        }
    }

    private fun showConsentPromptNotification(context: Context, sessionId: String, parentName: String) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID_REQUESTS,
                "Screen View Requests",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifies when a parent requests to view the screen"
                enableVibration(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            manager.createNotificationChannel(channel)
        }

        val consentIntent = Intent(context, MediaProjectionConsentActivity::class.java).apply {
            putExtra(MediaProjectionConsentActivity.EXTRA_SESSION_ID, sessionId)
            putExtra(MediaProjectionConsentActivity.EXTRA_PARENT_NAME, parentName)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            sessionId.hashCode(),
            consentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID_REQUESTS)
            .setContentTitle("Screen View Requested")
            .setContentText("$parentName requested to view this device's screen.")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .addAction(android.R.drawable.ic_media_play, "Authorize Screen View", pendingIntent)
            .build()

        manager.notify(NOTIFICATION_ID_REQUEST, notification)
    }
}`
  },
  {
    name: 'AndroidManifest.xml',
    path: 'android/app/src/main/AndroidManifest.xml',
    language: 'xml',
    category: 'android',
    content: `<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.parental.screenmirror">

    <!-- STRICTLY SCOPED PERMISSIONS -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.VIBRATE" />

    <application
        android:label="ScreenMirror"
        android:name="\${applicationName}"
        android:icon="@mipmap/ic_launcher">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <activity
            android:name=".MediaProjectionConsentActivity"
            android:exported="false"
            android:theme="@android:style/Theme.Translucent.NoTitleBar" />

        <!-- stopWithTask="false" ensures Foreground Service survives Recents swipe -->
        <service
            android:name=".ScreenCaptureService"
            android:enabled="true"
            android:exported="false"
            android:stopWithTask="false"
            android:foregroundServiceType="mediaProjection" />

        <receiver
            android:name=".BootReceiver"
            android:exported="true"
            android:enabled="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
            </intent-filter>
        </receiver>

        <receiver
            android:name=".NativeSignalingReceiver"
            android:exported="false">
            <intent-filter>
                <action android:name="com.parental.screenmirror.ACTION_REMOTE_REQUEST" />
            </intent-filter>
        </receiver>
    </application>
</manifest>`
  },
  {
    name: 'enums.dart',
    path: 'lib/core/enums.dart',
    language: 'dart',
    category: 'flutter',
    content: `/// Domain-wide Enums for the Remote Screen Mirroring Suite

enum DeviceStatus {
  deviceNotConfigured,
  deviceConfigured,
  ready,
  mirroring,
  stopped,
  error;
}

enum NativeSessionState {
  idle,
  ready,
  starting,
  capturing,
  connecting,
  streaming,
  reconnecting,
  stopping,
  stopped,
  revoked,
  error,
  reauthorizationRequired;
}

enum ParentPresenceState {
  online,
  offline,
  ready,
  mirroring,
  reconnecting,
  authorizationRequired,
  unavailable;
}

enum MirrorSessionState {
  idle,
  requested,
  connecting,
  connected,
  disconnected,
  reconnecting,
  failed,
  ended;
}`
  },
  {
    name: 'screen_capture_service.dart',
    path: 'lib/services/screen_capture_service.dart',
    language: 'dart',
    category: 'flutter',
    content: `import 'dart:async';
import 'package:flutter/services.dart';
import '../core/enums.dart';

class ScreenCaptureService {
  static const MethodChannel _methodChannel = MethodChannel('com.parental.screenmirror/capture');
  static const EventChannel _eventChannel = EventChannel('com.parental.screenmirror/events');

  final StreamController<NativeSessionState> _nativeStateController = StreamController<NativeSessionState>.broadcast();
  final StreamController<Map<String, String>> _networkChangeController = StreamController<Map<String, String>>.broadcast();

  Stream<NativeSessionState> get onNativeStateChanged => _nativeStateController.stream;
  Stream<Map<String, String>> get onNetworkChanged => _networkChangeController.stream;

  Future<int?> requestMediaProjectionPermission() async {
    return await _methodChannel.invokeMethod<int>('requestProjectionPermission');
  }

  Future<bool> stopCapture() async {
    final res = await _methodChannel.invokeMethod<bool>('stopCapture');
    return res ?? false;
  }

  Future<void> savePairingToNative({
    required String deviceId,
    required String deviceName,
    required String parentId,
    required String parentName,
    required String endpoint,
  }) async {
    await _methodChannel.invokeMethod('savePairing', {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'parentId': parentId,
      'parentName': parentName,
      'endpoint': endpoint,
    });
  }

  Future<bool> isBatteryOptimizationIgnored() async {
    return await _methodChannel.invokeMethod<bool>('isBatteryOptimizationIgnored') ?? false;
  }
}`
  },
  {
    name: 'schema.sql',
    path: 'backend/supabase/schema.sql',
    language: 'sql',
    category: 'backend',
    content: `-- PostgreSQL schema for remote screen mirroring parental control
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('parent', 'child')),
    display_name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS public.devices (
    id TEXT PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    device_name TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'android',
    presence_state TEXT NOT NULL DEFAULT 'READY',
    is_battery_exempted BOOLEAN NOT NULL DEFAULT FALSE,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.parent_child_links (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    child_device_id TEXT NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE(parent_user_id, child_device_id)
);

CREATE TABLE IF NOT EXISTS public.mirroring_sessions (
    id TEXT PRIMARY KEY,
    parent_id UUID NOT NULL REFERENCES public.users(id),
    child_device_id TEXT NOT NULL REFERENCES public.devices(id),
    status TEXT NOT NULL DEFAULT 'REQUESTED',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at TIMESTAMPTZ
);

ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parent_child_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mirroring_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Parents can view linked child devices"
    ON public.devices FOR SELECT
    USING (id IN (SELECT child_device_id FROM public.parent_child_links WHERE parent_user_id = auth.uid()));`
  },
  {
    name: 'get-turn-credentials.ts',
    path: 'backend/edge-functions/get-turn-credentials.ts',
    language: 'typescript',
    category: 'backend',
    content: `import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createHmac } from "https://deno.land/std@0.168.0/node/crypto.ts";

const TURN_SECRET = Deno.env.get("TURN_SHARED_SECRET") || "fallback_secret";

serve(async (req: Request) => {
  const ttlSeconds = 7200;
  const expiryTimestamp = Math.floor(Date.now() / 1000) + ttlSeconds;
  const username = \`\${expiryTimestamp}:screen_mirror_user\`;
  const hmac = createHmac("sha1", TURN_SECRET);
  hmac.update(username);
  const credential = hmac.digest("base64");

  return new Response(
    JSON.stringify({
      iceServers: [
        { urls: "stun:stun.l.google.com:19302" },
        { urls: ["turn:turn.screenmirror.internal:3478?transport=udp"], username, credential }
      ],
      ttl: ttlSeconds
    }),
    { headers: { "Content-Type": "application/json" } }
  );
});`
  }
];
