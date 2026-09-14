package com.parental.screenmirror

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
 * Demonstrates the native signaling pipeline:
 * 1. Validates parent identity against locally persisted pairing info
 * 2. Does NOT attempt hidden capture (impossible and banned on Android 14+)
 * 3. Shows high-priority heads-up notification bringing Child into the
 *    legitimate MediaProjection consent flow via MediaProjectionConsentActivity.
 */
class NativeSignalingReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "NativeSignalingReceiver"
        const val ACTION_REMOTE_REQUEST = "com.parental.screenmirror.ACTION_REMOTE_REQUEST"
        const val CHANNEL_ID_REQUESTS = "screen_mirror_requests_channel"
        const val NOTIFICATION_ID_REQUEST = 40402

        const val EXTRA_SESSION_ID = "session_id"
        const val EXTRA_PARENT_ID = "parent_id"
        const val EXTRA_PARENT_NAME = "parent_name"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.i(TAG, "[SIGNALING] NativeSignalingReceiver received action: $action")

        if (action == ACTION_REMOTE_REQUEST) {
            val sessionId = intent.getStringExtra(EXTRA_SESSION_ID) ?: ""
            val parentId = intent.getStringExtra(EXTRA_PARENT_ID) ?: ""
            val parentName = intent.getStringExtra(EXTRA_PARENT_NAME) ?: "Parent"

            // 1. Verify pairing
            val savedParentId = NativeStorageHelper.getPairedParentId(context)
            if (savedParentId == null || savedParentId != parentId) {
                Log.w(TAG, "[SECURITY] Rejected unauthorized request from unlinked parent: $parentId")
                return
            }

            Log.i(TAG, "[SESSION] Received legitimate session request from paired parent: $parentName (Session: $sessionId)")
            NativeStorageHelper.saveLastSessionId(context, sessionId)
            NativeCaptureManager.transitionTo(NativeSessionState.STARTING, "Incoming parent request")

            // 2. Present user-visible prompt to enter consent flow
            showConsentPromptNotification(context, sessionId, parentName)
        }
    }

    private fun showConsentPromptNotification(context: Context, sessionId: String, parentName: String) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

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
            notificationManager.createNotificationChannel(channel)
        }

        // Full-screen intent or tap opens MediaProjectionConsentActivity
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

        notificationManager.notify(NOTIFICATION_ID_REQUEST, notification)
        Log.i(TAG, "[SIGNALING] Dispatched high-priority notification for user authorization")
    }
}
