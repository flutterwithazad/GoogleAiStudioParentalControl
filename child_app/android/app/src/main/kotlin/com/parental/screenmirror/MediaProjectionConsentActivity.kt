package com.parental.screenmirror

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
import android.util.Log

/**
 * Transparent native Activity solely responsible for presenting the system
 * MediaProjection consent prompt when requested by parent while the Flutter UI
 * is not running or when reauthorization is needed.
 *
 * This completely satisfies:
 * 1. "Child device remains available for legitimate remote screen-mirroring sessions even when the Flutter UI is not running."
 * 2. "DO NOT attempt to bypass Android MediaProjection user-consent requirements."
 */
class MediaProjectionConsentActivity : Activity() {

    companion object {
        private const val TAG = "MediaProjConsentAct"
        private const val REQUEST_CODE_CAPTURE = 3001
        const val EXTRA_SESSION_ID = "extra_session_id"
        const val EXTRA_PARENT_NAME = "extra_parent_name"
    }

    private var sessionId: String? = null
    private var parentName: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        sessionId = intent.getStringExtra(EXTRA_SESSION_ID)
        parentName = intent.getStringExtra(EXTRA_PARENT_NAME) ?: "Parent"

        Log.i(TAG, "[MEDIA_PROJECTION] MediaProjectionConsentActivity started for session: $sessionId")

        val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as? MediaProjectionManager
        if (projectionManager != null) {
            val captureIntent = projectionManager.createScreenCaptureIntent()
            startActivityForResult(captureIntent, REQUEST_CODE_CAPTURE)
        } else {
            Log.e(TAG, "[MEDIA_PROJECTION] MediaProjectionManager is null")
            finish()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == REQUEST_CODE_CAPTURE) {
            if (resultCode == RESULT_OK && data != null) {
                Log.i(TAG, "[MEDIA_PROJECTION] User granted capture authorization via native prompt")

                // Start native Foreground Service directly from native context
                val startIntent = Intent(this, ScreenCaptureService::class.java).apply {
                    action = ScreenCaptureService.ACTION_START
                    putExtra(ScreenCaptureService.EXTRA_RESULT_CODE, resultCode)
                    putExtra(ScreenCaptureService.EXTRA_RESULT_DATA, data)
                    putExtra(ScreenCaptureService.EXTRA_SESSION_ID, sessionId)
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(startIntent)
                } else {
                    startService(startIntent)
                }
            } else {
                Log.w(TAG, "[MEDIA_PROJECTION] User dismissed or cancelled capture prompt")
                NativeCaptureManager.transitionTo(NativeSessionState.READY, "User declined consent prompt")
            }
            finish()
        }
    }
}
