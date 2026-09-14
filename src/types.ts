export type DeviceState = 'DEVICE_NOT_CONFIGURED' | 'DEVICE_CONFIGURED' | 'READY' | 'MIRRORING' | 'STOPPED' | 'ERROR';
export type SessionState = 'IDLE' | 'REQUESTED' | 'CONNECTING' | 'CONNECTED' | 'DISCONNECTED' | 'RECONNECTING' | 'FAILED' | 'ENDED';
export type QualityProfile = 'POOR_NETWORK' | 'NORMAL_NETWORK' | 'GOOD_NETWORK';

export type NativeSessionState =
  | 'IDLE'
  | 'READY'
  | 'STARTING'
  | 'CAPTURING'
  | 'CONNECTING'
  | 'STREAMING'
  | 'RECONNECTING'
  | 'STOPPING'
  | 'STOPPED'
  | 'REVOKED'
  | 'ERROR'
  | 'REAUTHORIZATION_REQUIRED';

export type ParentPresenceState =
  | 'ONLINE'
  | 'OFFLINE'
  | 'READY'
  | 'MIRRORING'
  | 'RECONNECTING'
  | 'AUTHORIZATION_REQUIRED'
  | 'UNAVAILABLE';

export interface WebRTCStatsData {
  width: number;
  height: number;
  fps: number;
  bitrateKbps: number;
  roundTripTimeMs: number;
}

export interface StructuredLog {
  id: string;
  timestamp: string;
  category: '[SCREEN_CAPTURE]' | '[MEDIA_PROJECTION]' | '[FOREGROUND_SERVICE]' | '[WEBRTC]' | '[SIGNALING]' | '[SESSION]';
  message: string;
  level: 'info' | 'warn' | 'error';
}

export interface FileItem {
  name: string;
  path: string;
  language: string;
  content: string;
  category: 'android' | 'flutter' | 'backend' | 'docs';
}
