package com.parental.screenmirror

/**
 * Native Android State Machine for the remote screen-mirroring lifecycle.
 *
 * This state machine is owned by the native Android service layer and operates
 * independently of whether the Flutter Activity/UI is running, backgrounded,
 * destroyed, or removed from Recents.
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
}
