/// Shared domain enums for the Parental Screen Mirroring Suite.

enum DeviceStatus {
  notConfigured,
  pairing,
  configured,
  ready,
  starting,
  capturing,
  connecting,
  streaming,
  reconnecting,
  stopping,
  stopped,
  revoked,
  reauthorizationRequired,
  error,
  offline;

  String toDisplayString() {
    switch (this) {
      case DeviceStatus.notConfigured:
        return 'Not Configured';
      case DeviceStatus.pairing:
        return 'Pairing...';
      case DeviceStatus.configured:
        return 'Configured';
      case DeviceStatus.ready:
        return 'Ready for Mirroring';
      case DeviceStatus.starting:
        return 'Starting Service';
      case DeviceStatus.capturing:
        return 'Capturing Screen';
      case DeviceStatus.connecting:
        return 'Connecting WebRTC';
      case DeviceStatus.streaming:
        return 'Streaming to Parent';
      case DeviceStatus.reconnecting:
        return 'Reconnecting Network';
      case DeviceStatus.stopping:
        return 'Stopping Session';
      case DeviceStatus.stopped:
        return 'Stopped';
      case DeviceStatus.revoked:
        return 'Revoked by Android OS';
      case DeviceStatus.reauthorizationRequired:
        return 'Re-authorization Required (Token Expired)';
      case DeviceStatus.error:
        return 'Error Occurred';
      case DeviceStatus.offline:
        return 'Offline';
    }
  }
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
  reauthorizationRequired,
  error;

  String toDisplayString() {
    switch (this) {
      case NativeSessionState.idle:
        return 'Native Idle';
      case NativeSessionState.ready:
        return 'Native Ready';
      case NativeSessionState.starting:
        return 'Native Starting';
      case NativeSessionState.capturing:
        return 'VirtualDisplay Capturing';
      case NativeSessionState.connecting:
        return 'WebRTC Connecting';
      case NativeSessionState.streaming:
        return 'Hardware Encoder Streaming';
      case NativeSessionState.reconnecting:
        return 'ICE Restart In-Flight';
      case NativeSessionState.stopping:
        return 'Tearing Down Pipeline';
      case NativeSessionState.stopped:
        return 'Service Stopped';
      case NativeSessionState.revoked:
        return 'Revoked via Android Privacy Chip';
      case NativeSessionState.reauthorizationRequired:
        return 'Re-authorization Required (Android 14+ Token Expired)';
      case NativeSessionState.error:
        return 'Native Error';
    }
  }
}

enum ParentPresenceState {
  online,
  ready,
  mirroring,
  reconnecting,
  authorizationRequired,
  offline,
  unavailable;

  String toDisplayString() {
    switch (this) {
      case ParentPresenceState.online:
        return 'Online';
      case ParentPresenceState.ready:
        return 'Ready';
      case ParentPresenceState.mirroring:
        return 'Mirroring Active';
      case ParentPresenceState.reconnecting:
        return 'Reconnecting...';
      case ParentPresenceState.authorizationRequired:
        return 'Auth Required';
      case ParentPresenceState.offline:
        return 'Offline';
      case ParentPresenceState.unavailable:
        return 'Unavailable';
    }
  }
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

  String toDisplayString() {
    switch (this) {
      case MirrorSessionState.idle:
        return 'Idle';
      case MirrorSessionState.requested:
        return 'Session Requested';
      case MirrorSessionState.connecting:
        return 'Connecting...';
      case MirrorSessionState.connected:
        return 'Connected (Streaming)';
      case MirrorSessionState.disconnected:
        return 'Disconnected';
      case MirrorSessionState.reconnecting:
        return 'Reconnecting...';
      case MirrorSessionState.failed:
        return 'Connection Failed';
      case MirrorSessionState.ended:
        return 'Session Ended';
    }
  }
}
