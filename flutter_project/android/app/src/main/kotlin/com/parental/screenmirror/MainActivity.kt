package com.parental.screenmirror

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity(), WebRTCBridge.ActivityCallback {

    companion object {
        private const val TAG = "MainActivity"
        const val REQUEST_MEDIA_PROJECTION = 1002

        var lastResultCode: Int = 0
        var lastResultData: Intent? = null
    }

    private var mediaProjectionManager: MediaProjectionManager? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WebRTCBridge.init(flutterEngine.dartExecutor.binaryMessenger, applicationContext, this)
    }

    override fun requestMediaProjection() {
        if (mediaProjectionManager == null) {
            mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        }

        try {
            val captureIntent = mediaProjectionManager?.createScreenCaptureIntent()
            if (captureIntent != null) {
                Log.i(TAG, "[MEDIA_PROJECTION] Launching system MediaProjection consent dialog")
                startActivityForResult(captureIntent, REQUEST_MEDIA_PROJECTION)
            } else {
                Log.e(TAG, "[MEDIA_PROJECTION] Failed to create screen capture intent")
                WebRTCBridge.notifyError("INTENT_ERROR", "Could not create MediaProjection intent")
            }
        } catch (e: Exception) {
            Log.e(TAG, "[MEDIA_PROJECTION] Error requesting projection intent", e)
            WebRTCBridge.notifyError("LAUNCH_ERROR", e.localizedMessage ?: "Failed to launch consent dialog")
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == REQUEST_MEDIA_PROJECTION) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                Log.i(TAG, "[MEDIA_PROJECTION] User granted screen capture permission")
                lastResultCode = resultCode
                lastResultData = data
                WebRTCBridge.notifyPermissionResult(true, resultCode)
            } else {
                Log.w(TAG, "[MEDIA_PROJECTION] User denied or dismissed screen capture permission")
                lastResultCode = 0
                lastResultData = null
                WebRTCBridge.notifyPermissionResult(false, resultCode)
            }
        }
    }
}
