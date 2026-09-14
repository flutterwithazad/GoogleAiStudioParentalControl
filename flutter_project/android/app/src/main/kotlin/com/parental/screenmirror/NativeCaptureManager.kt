package com.parental.screenmirror

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.util.Log

/**
 * Central Native Manager for the screen capture lifecycle.
 *
 * Owns the native state machine and network monitoring independently of Flutter.
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
        Log.i(TAG, "[SESSION] NativeCaptureManager initialized with state: $currentState")
    }

    fun addStateListener(listener: (NativeSessionState) -> Unit) {
        stateListeners.add(listener)
        listener(currentState)
    }

    fun removeStateListener(listener: (NativeSessionState) -> Unit) {
        stateListeners.remove(listener)
    }

    fun getCurrentState(): NativeSessionState = currentState

    fun transitionTo(newState: NativeSessionState, reason: String = "") {
        if (currentState == newState) return

        Log.i(TAG, "[SESSION] Native state transition: $currentState -> $newState ${if (reason.isNotEmpty()) "($reason)" else ""}")
        currentState = newState

        applicationContext?.let { ctx ->
            NativeStorageHelper.saveNativeState(ctx, newState)
        }

        // Notify in-process listeners (Flutter EventChannel, Service, etc.)
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

                    Log.i(TAG, "[WEBRTC] Network available: $currentType (Previous: $lastNetworkType)")

                    if (lastNetworkType.isNotEmpty() && lastNetworkType != currentType) {
                        Log.i(TAG, "[WEBRTC] Network handoff detected: $lastNetworkType -> $currentType. Keeping capture alive, initiating ICE restart.")
                        if (currentState == NativeSessionState.STREAMING || currentState == NativeSessionState.CAPTURING) {
                            transitionTo(NativeSessionState.RECONNECTING, "Network handoff $lastNetworkType -> $currentType")
                            WebRTCBridge.notifyNetworkChange(lastNetworkType, currentType)
                        }
                    }
                    lastNetworkType = currentType
                }

                override fun onLost(network: Network) {
                    Log.w(TAG, "[WEBRTC] Network connection lost. Awaiting fallback route...")
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
}
