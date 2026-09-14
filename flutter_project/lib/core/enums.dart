/// Domain-wide Enums for the Remote Screen Mirroring Suite

enum DeviceStatus {
  deviceNotConfigured,
  deviceConfigured,
  ready,
  mirroring,
  stopped,
  error;

  String toDisplayString() {
    switch (this) {
      case DeviceStatus.deviceNotConfigured:
        return 'Not Configured';
      case DeviceStatus.deviceConfigured:
        return 'Configured';
      case DeviceStatus.ready:
        return 'Ready';
      case DeviceStatus.mirroring:
        return 'Mirroring Active';
      case DeviceStatus.stopped:
        return 'Stopped';
      case DeviceStatus.error:
        return 'Error';
    }
  }
}

/// Service-owned Native State Machine
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
  error,
  reauthorizationRequired;

  String toDisplayString() {
    switch (this) {
      case NativeSessionState.idle:
        return 'Idle';
      case NativeSessionState.ready:
        return 'Ready for Request';
      case NativeSessionState.starting:
        return 'Starting Capture Service';
      case NativeSessionState.capturing:
        return 'Screen Capture Active';
      case NativeSessionState.connecting:
        return 'Connecting WebRTC';
      case NativeSessionState.streaming:
        return 'Streaming to Parent';
      case NativeSessionState.reconnecting:
        return 'Reconnecting Network (ICE Restart)';
      case NativeSessionState.stopping:
        return 'Stopping Session';
      case NativeSessionState.stopped:
        return 'Stopped';
      case NativeSessionState.revoked:
        return 'Revoked by User / System';
      case NativeSessionState.error:
        return 'Error';
      case NativeSessionState.reauthorizationRequired:
        return 'Reauthorization Required (Android 14+ Token Expired)';
    }
  }

  static NativeSessionState fromString(String name) {
    switch (name.toUpperCase()) {
      case 'READY':
        return NativeSessionState.ready;
      case 'STARTING':
        return NativeSessionState.starting;
      case 'CAPTURING':
        return NativeSessionState.capturing;
      case 'CONNECTING':
        return NativeSessionState.connecting;
      case 'STREAMING':
      case 'MIRRORING':
        return NativeSessionState.streaming;
      case 'RECONNECTING':
        return NativeSessionState.reconnecting;
      case 'STOPPING':
        return NativeSessionState.stopping;
      case 'STOPPED':
        return NativeSessionState.stopped;
      case 'REVOKED':
        return NativeSessionState.revoked;
      case 'ERROR':
        return NativeSessionState.error;
      case 'REAUTHORIZATION_REQUIRED':
        return NativeSessionState.reauthorizationRequired;
      default:
        return NativeSessionState.idle;
    }
  }
}

/// Parent "Anytime" Presence State as strictly requested:
/// ONLINE, OFFLINE, READY, MIRRORING, RECONNECTING, AUTHORIZATION_REQUIRED, UNAVAILABLE
enum ParentPresenceState {
  online,
  offline,
  ready,
  mirroring,
  reconnecting,
  authorizationRequired,
  unavailable;

  String toDisplayString() {
    switch (this) {
      case ParentPresenceState.online:
        return 'Online';
      case ParentPresenceState.offline:
        return 'Offline';
      case ParentPresenceState.ready:
        return 'Ready';
      case ParentPresenceState.mirroring:
        return 'Mirroring Active';
      case ParentPresenceState.reconnecting:
        return 'Reconnecting...';
      case ParentPresenceState.authorizationRequired:
        return 'Authorization Required';
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
        return 'Live';
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

enum QualityProfile {
  poorNetwork(width: 854, height: 480, fps: 15, bitrateKbps: 600, label: 'Poor (480p / 15fps)'),
  normalNetwork(width: 1280, height: 720, fps: 25, bitrateKbps: 1400, label: 'Normal (720p / 25fps)'),
  goodNetwork(width: 1280, height: 720, fps: 30, bitrateKbps: 2400, label: 'Good (720p / 30fps)');

  const QualityProfile({
    required this.width,
    required this.height,
    required this.fps,
    required this.bitrateKbps,
    required this.label,
  });

  final int width;
  final int height;
  final int fps;
  final int bitrateKbps;
  final String label;
}

enum LogCategory {
  screenCapture,
  mediaProjection,
  foregroundService,
  webrtc,
  signaling,
  session;

  String get tag {
    switch (this) {
      case LogCategory.screenCapture:
        return '[SCREEN_CAPTURE]';
      case LogCategory.mediaProjection:
        return '[MEDIA_PROJECTION]';
      case LogCategory.foregroundService:
        return '[FOREGROUND_SERVICE]';
      case LogCategory.webrtc:
        return '[WEBRTC]';
      case LogCategory.signaling:
        return '[SIGNALING]';
      case LogCategory.session:
        return '[SESSION]';
    }
  }
}
