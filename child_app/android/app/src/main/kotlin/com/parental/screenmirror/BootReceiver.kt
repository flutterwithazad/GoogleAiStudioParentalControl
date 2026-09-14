package com.parental.screenmirror

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Boot Receiver executed on device reboot.
 *
 * Restores non-sensitive configuration and pairing, establishes presence,
 * and leaves the device in the READY state awaiting parental requests.
 *
 * Strictly NEVER attempts to start MediaProjection or capture on reboot,
 * as Android MediaProjection explicitly requires user consent.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON"
        ) {
            Log.i(TAG, "[SESSION] System boot completed: Initializing ScreenMirror boot restoration")

            if (!NativeStorageHelper.isConfigured(context)) {
                Log.i(TAG, "[SESSION] Device not paired yet. Awaiting initial setup.")
                return
            }

            val deviceId = NativeStorageHelper.getDeviceId(context)
            val parentId = NativeStorageHelper.getPairedParentId(context)
            Log.i(TAG, "[SESSION] Restored pairing credentials for device: $deviceId with parent: $parentId")

            // Initialize manager and transition to READY
            NativeCaptureManager.init(context)
            NativeCaptureManager.transitionTo(NativeSessionState.READY, "Restored after device boot")

            // Any background signaling listener or presence ping can be scheduled safely here
            Log.i(TAG, "[SESSION] Device presence restored to READY. Awaiting parental session request.")
        }
    }
}
