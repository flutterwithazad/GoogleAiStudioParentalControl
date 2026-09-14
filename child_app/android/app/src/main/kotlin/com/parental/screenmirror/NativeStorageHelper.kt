package com.parental.screenmirror

import android.content.Context
import android.content.SharedPreferences
import android.util.Log

/**
 * Safe Native Storage Helper.
 *
 * Persists ONLY non-sensitive operational state:
 * - Paired device ID
 * - Paired parent ID & name
 * - Device configuration status
 * - Last known session ID
 * - Signaling endpoint
 *
 * CRITICAL SECURITY & ANDROID PRIVACY RULE:
 * This helper NEVER serializes or stores MediaProjection objects,
 * intents, or tokens. MediaProjection authorization must remain an
 * ephemeral Android-controlled capability.
 */
object NativeStorageHelper {

    private const val TAG = "NativeStorageHelper"
    private const val PREFS_NAME = "com.parental.screenmirror.native_prefs"

    private const val KEY_IS_CONFIGURED = "is_configured"
    private const val KEY_DEVICE_ID = "device_id"
    private const val KEY_DEVICE_NAME = "device_name"
    private const val KEY_PAIRED_PARENT_ID = "paired_parent_id"
    private const val KEY_PAIRED_PARENT_NAME = "paired_parent_name"
    private const val KEY_LAST_SESSION_ID = "last_session_id"
    private const val KEY_SIGNALING_ENDPOINT = "signaling_endpoint"
    private const val KEY_NATIVE_STATE = "native_state"

    private fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    fun savePairingInfo(
        context: Context,
        deviceId: String,
        deviceName: String,
        parentId: String,
        parentName: String,
        endpoint: String
    ) {
        getPrefs(context).edit().apply {
            putBoolean(KEY_IS_CONFIGURED, true)
            putString(KEY_DEVICE_ID, deviceId)
            putString(KEY_DEVICE_NAME, deviceName)
            putString(KEY_PAIRED_PARENT_ID, parentId)
            putString(KEY_PAIRED_PARENT_NAME, parentName)
            putString(KEY_SIGNALING_ENDPOINT, endpoint)
            apply()
        }
        Log.i(TAG, "[STORAGE] Saved safe pairing info for device: $deviceId, parent: $parentName")
    }

    fun isConfigured(context: Context): Boolean {
        return getPrefs(context).getBoolean(KEY_IS_CONFIGURED, false)
    }

    fun getDeviceId(context: Context): String? {
        return getPrefs(context).getString(KEY_DEVICE_ID, null)
    }

    fun getPairedParentId(context: Context): String? {
        return getPrefs(context).getString(KEY_PAIRED_PARENT_ID, null)
    }

    fun getPairedParentName(context: Context): String? {
        return getPrefs(context).getString(KEY_PAIRED_PARENT_NAME, "Parent")
    }

    fun getSignalingEndpoint(context: Context): String? {
        return getPrefs(context).getString(KEY_SIGNALING_ENDPOINT, null)
    }

    fun saveLastSessionId(context: Context, sessionId: String?) {
        getPrefs(context).edit().putString(KEY_LAST_SESSION_ID, sessionId).apply()
    }

    fun getLastSessionId(context: Context): String? {
        return getPrefs(context).getString(KEY_LAST_SESSION_ID, null)
    }

    fun saveNativeState(context: Context, state: NativeSessionState) {
        getPrefs(context).edit().putString(KEY_NATIVE_STATE, state.name).apply()
    }

    fun getNativeState(context: Context): NativeSessionState {
        val name = getPrefs(context).getString(KEY_NATIVE_STATE, NativeSessionState.IDLE.name)
        return try {
            NativeSessionState.valueOf(name ?: NativeSessionState.IDLE.name)
        } catch (e: Exception) {
            NativeSessionState.IDLE
        }
    }

    fun clearPairing(context: Context) {
        getPrefs(context).edit().clear().apply()
        Log.i(TAG, "[STORAGE] Cleared pairing data")
    }
}
