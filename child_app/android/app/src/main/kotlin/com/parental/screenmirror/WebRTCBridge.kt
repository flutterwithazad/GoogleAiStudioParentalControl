package com.parental.screenmirror

import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.Surface
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Platform channel bridge between Flutter Dart and Android Kotlin.
 *
 * Exposes:
 * - Native state machine observation
 * - Foreground capture control
 * - Battery optimization & OEM settings triggers
 * - Surface exchange with WebRTC
 */
object WebRTCBridge : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private const val TAG = "WebRTCBridge"
    private const val METHOD_CHANNEL = "com.parental.screenmirror/capture"
    private const val EVENT_CHANNEL = "com.parental.screenmirror/events"

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var applicationContext: Context? = null
    private var activityCallback: ActivityCallback? = null

    private var videoInputSurface: Surface? = null

    interface ActivityCallback {
        fun requestMediaProjection()
    }

    fun init(messenger: BinaryMessenger, context: Context, callback: ActivityCallback) {
        this.applicationContext = context.applicationContext
        this.activityCallback = callback

        NativeCaptureManager.init(context)

        methodChannel = MethodChannel(messenger, METHOD_CHANNEL).apply {
            setMethodCallHandler(this@WebRTCBridge)
        }
        eventChannel = EventChannel(messenger, EVENT_CHANNEL).apply {
            setStreamHandler(this@WebRTCBridge)
        }
        Log.i(TAG, "[WEBRTC] WebRTCBridge platform channels initialized")
    }

    fun setVideoInputSurface(surface: Surface?) {
        this.videoInputSurface = surface
        Log.i(TAG, "[WEBRTC] Video input surface updated: $surface")
    }

    fun getVideoInputSurface(): Surface? = videoInputSurface

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = applicationContext
        if (context == null) {
            result.error("NO_CONTEXT", "Application context is null", null)
            return
        }

        when (call.method) {
            "getNativeState" -> {
                result.success(NativeCaptureManager.getCurrentState().name)
            }
            "requestProjectionPermission" -> {
                Log.i(TAG, "[MEDIA_PROJECTION] Dart requested projection permission")
                activityCallback?.requestMediaProjection()
                result.success(true)
            }
            "startForegroundCapture" -> {
                val resultCode = call.argument<Int>("resultCode") ?: 0
                val resultDataIntent = MainActivity.consumeResultData()
                val sessionId = call.argument<String>("sessionId")
                val profileName = call.argument<String>("profile") ?: "NORMAL_NETWORK"
                val profile = try {
                    MediaProjectionHelper.QualityProfile.valueOf(profileName)
                } catch (e: Exception) {
                    MediaProjectionHelper.QualityProfile.NORMAL_NETWORK
                }

                if (resultCode == 0 || resultDataIntent == null) {
                    Log.e(TAG, "[FOREGROUND_SERVICE] Cannot start capture: missing result token")
                    result.error("NO_TOKEN", "MediaProjection authorization token is missing or expired", null)
                    return
                }

                val config = MediaProjectionHelper.getCaptureConfig(context, profile)
                val intent = Intent(context, ScreenCaptureService::class.java).apply {
                    action = ScreenCaptureService.ACTION_START
                    putExtra(ScreenCaptureService.EXTRA_RESULT_CODE, resultCode)
                    putExtra(ScreenCaptureService.EXTRA_RESULT_DATA, resultDataIntent)
                    putExtra(ScreenCaptureService.EXTRA_WIDTH, config.width)
                    putExtra(ScreenCaptureService.EXTRA_HEIGHT, config.height)
                    putExtra(ScreenCaptureService.EXTRA_DPI, config.dpi)
                    putExtra(ScreenCaptureService.EXTRA_SESSION_ID, sessionId)
                }

                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }

                result.success(mapOf(
                    "width" to config.width,
                    "height" to config.height,
                    "fps" to config.targetFps,
                    "bitrate" to config.bitrateKbps
                ))
            }
            "stopCapture" -> {
                Log.i(TAG, "[FOREGROUND_SERVICE] Dart requested stopCapture")
                val intent = Intent(context, ScreenCaptureService::class.java).apply {
                    action = ScreenCaptureService.ACTION_STOP
                }
                context.startService(intent)
                result.success(true)
            }
            "isCapturing" -> {
                result.success(ScreenCaptureService.isRunning)
            }
            "savePairing" -> {
                val deviceId = call.argument<String>("deviceId") ?: ""
                val deviceName = call.argument<String>("deviceName") ?: ""
                val parentId = call.argument<String>("parentId") ?: ""
                val parentName = call.argument<String>("parentName") ?: ""
                val endpoint = call.argument<String>("endpoint") ?: ""
                NativeStorageHelper.savePairingInfo(context, deviceId, deviceName, parentId, parentName, endpoint)
                result.success(true)
            }
            "clearPairing" -> {
                NativeStorageHelper.clearPairing(context)
                result.success(true)
            }
            "isBatteryOptimizationIgnored" -> {
                result.success(OemBatteryHelper.isIgnoringBatteryOptimizations(context))
            }
            "requestIgnoreBatteryOptimization" -> {
                val intent = OemBatteryHelper.getRequestIgnoreBatteryIntent(context)
                if (intent != null) {
                    context.startActivity(intent)
                    result.success(true)
                } else {
                    result.success(false)
                }
            }
            "isAggressiveOem" -> {
                result.success(OemBatteryHelper.isAggressiveOem())
            }
            "getOemManufacturer" -> {
                result.success(OemBatteryHelper.getManufacturerName())
            }
            "openOemBatterySettings" -> {
                val intent = OemBatteryHelper.getOemSpecificSettingsIntent(context)
                if (intent != null) {
                    context.startActivity(intent)
                    result.success(true)
                } else {
                    result.success(false)
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
        // Immediately emit current state
        events?.success(mapOf(
            "type" to "STATE_CHANGED",
            "state" to NativeCaptureManager.getCurrentState().name
        ))
    }

    override fun onCancel(arguments: Any?) {
        this.eventSink = null
    }

    fun notifyStateChanged(state: String) {
        eventSink?.success(mapOf(
            "type" to "STATE_CHANGED",
            "state" to state
        ))
    }

    fun notifyPermissionResult(granted: Boolean, resultCode: Int) {
        eventSink?.success(mapOf(
            "type" to "PERMISSION_RESULT",
            "granted" to granted,
            "resultCode" to resultCode
        ))
    }

    fun notifyNetworkChange(previousType: String, currentType: String) {
        eventSink?.success(mapOf(
            "type" to "NETWORK_CHANGED",
            "previousType" to previousType,
            "currentType" to currentType
        ))
    }

    fun notifyError(code: String, message: String) {
        eventSink?.success(mapOf(
            "type" to "ERROR",
            "code" to code,
            "message" to message
        ))
    }
}
