package com.parental.screenmirror

import android.content.Intent
import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Native Firebase Cloud Messaging (FCM) Service.
 *
 * This is the ONLY component capable of waking an Android device from killed state
 * when no foreground service is active.
 *
 * Protocol:
 * 1. Receives high-priority data message from backend when Parent clicks "VIEW SCREEN"
 * 2. Parses session_id, parent_id, and parent_name
 * 3. Verifies parent against locally encrypted pairing store
 * 4. Broadcasts Intent to NativeSignalingReceiver or directly posts Heads-Up notification
 *    to launch MediaProjectionConsentActivity.
 */
class FcmSignalingService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "FcmSignalingService"
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        Log.i(TAG, "[SIGNALING] FCM high-priority message received: ${remoteMessage.data}")

        val data = remoteMessage.data
        val messageType = data["type"] ?: ""

        if (messageType == "session_request") {
            val sessionId = data["session_id"] ?: ""
            val parentId = data["parent_id"] ?: ""
            val parentName = data["parent_name"] ?: "Parent"

            // Verify paired parent
            val savedParentId = NativeStorageHelper.getPairedParentId(applicationContext)
            if (savedParentId == null || savedParentId != parentId) {
                Log.w(TAG, "[SECURITY] Rejected FCM request: parentId $parentId does not match paired parent $savedParentId")
                return
            }

            Log.i(TAG, "[SESSION] Legitimate session request received via FCM wake. Forwarding to NativeSignalingReceiver.")
            val intent = Intent(applicationContext, NativeSignalingReceiver::class.java).apply {
                action = NativeSignalingReceiver.ACTION_REMOTE_REQUEST
                putExtra(NativeSignalingReceiver.EXTRA_SESSION_ID, sessionId)
                putExtra(NativeSignalingReceiver.EXTRA_PARENT_ID, parentId)
                putExtra(NativeSignalingReceiver.EXTRA_PARENT_NAME, parentName)
            }
            sendBroadcast(intent)
        }
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.i(TAG, "[SIGNALING] FCM registration token refreshed: $token")
        // Can be synced to Supabase devices table for routing parent requests
    }
}
