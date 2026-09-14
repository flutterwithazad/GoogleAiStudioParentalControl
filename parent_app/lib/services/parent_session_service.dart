import 'dart:async';
import 'package:screen_mirror_shared/enums.dart';
import 'package:screen_mirror_shared/logging/app_logger.dart';
import 'package:screen_mirror_shared/signaling/signaling_service.dart';
import 'package:screen_mirror_shared/webrtc/webrtc_service.dart';

class ParentSessionService {
  final SignalingService signalingService;
  final WebRTCService webRTCService;
  final String parentId;

  final StreamController<MirrorSessionState> _sessionStateController =
      StreamController<MirrorSessionState>.broadcast();
  final StreamController<ParentPresenceState> _presenceStateController =
      StreamController<ParentPresenceState>.broadcast();

  Stream<MirrorSessionState> get onSessionStateChanged => _sessionStateController.stream;
  Stream<ParentPresenceState> get onPresenceChanged => _presenceStateController.stream;

  String? _activeSessionId;
  String? _activeChildDeviceId;
  MirrorSessionState _currentState = MirrorSessionState.idle;

  String? get activeSessionId => _activeSessionId;
  MirrorSessionState get currentState => _currentState;

  ParentSessionService({
    required this.signalingService,
    required this.webRTCService,
    this.parentId = 'parent_admin_uuid',
  });

  void initialize() {
    AppLogger.session('Initializing ParentSessionService');

    signalingService.onSignalReceived.listen((signal) async {
      final type = signal['type'] as String?;
      final sessionId = signal['sessionId'] as String?;

      if (sessionId != null && _activeSessionId != null && sessionId != _activeSessionId) {
        return; // Ignore signals from other sessions
      }

      switch (type) {
        case 'answer':
          final sdp = signal['sdp'] as String?;
          if (sdp != null) {
            AppLogger.session('Received SDP Answer from child device');
            await webRTCService.setRemoteAnswer(sdp);
            _updateState(MirrorSessionState.connected);
          }
          break;

        case 'ice_candidate':
          final candidateMap = signal['candidate'] as Map<String, dynamic>?;
          if (candidateMap != null) {
            await webRTCService.addIceCandidate(candidateMap);
          }
          break;

        case 'session_end':
          AppLogger.session('Session ended by child or system: ${signal['reason']}');
          _cleanUpSession();
          _updateState(MirrorSessionState.ended);
          break;

        case 'presence_update':
          final presenceStr = signal['presence'] as String?;
          if (presenceStr != null) {
            _handlePresenceUpdate(presenceStr);
          }
          break;
      }
    });

    webRTCService.onIceCandidate.listen((candidate) {
      if (_activeSessionId != null && _activeChildDeviceId != null) {
        signalingService.sendIceCandidate(
          sessionId: _activeSessionId!,
          targetDeviceId: _activeChildDeviceId!,
          candidate: {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        );
      }
    });
  }

  Future<void> requestSession({required String childDeviceId}) async {
    AppLogger.session('Parent requesting screen mirroring session with child: $childDeviceId');
    _activeChildDeviceId = childDeviceId;
    _updateState(MirrorSessionState.connecting);

    try {
      _activeSessionId = await signalingService.createSession(
        parentId: parentId,
        childDeviceId: childDeviceId,
      );

      await signalingService.sendSessionRequest(
        sessionId: _activeSessionId!,
        targetDeviceId: childDeviceId,
        parentId: parentId,
        parentName: 'Parent',
      );

      await webRTCService.initializePeerConnection(isSender: false);

      // In parent-viewer role, child initiates video stream upon MediaProjection grant
      AppLogger.signaling('Session request dispatched to child: $_activeSessionId');
    } catch (e) {
      AppLogger.session('Failed to initiate mirroring session: $e');
      _updateState(MirrorSessionState.failed);
    }
  }

  Future<void> stopSession() async {
    if (_activeSessionId != null && _activeChildDeviceId != null) {
      AppLogger.session('Parent stopping active mirroring session: $_activeSessionId');
      await signalingService.endSession(
        sessionId: _activeSessionId!,
        targetDeviceId: _activeChildDeviceId!,
        reason: 'Stopped by parent user',
      );
    }
    await _cleanUpSession();
    _updateState(MirrorSessionState.ended);
  }

  Future<void> _cleanUpSession() async {
    _activeSessionId = null;
    _activeChildDeviceId = null;
    await webRTCService.dispose();
  }

  void _updateState(MirrorSessionState state) {
    _currentState = state;
    _sessionStateController.add(state);
    if (state == MirrorSessionState.connected) {
      _presenceStateController.add(ParentPresenceState.mirroring);
    } else if (state == MirrorSessionState.reconnecting) {
      _presenceStateController.add(ParentPresenceState.reconnecting);
    } else if (state == MirrorSessionState.ended || state == MirrorSessionState.idle) {
      _presenceStateController.add(ParentPresenceState.ready);
    }
  }

  void _handlePresenceUpdate(String presence) {
    switch (presence.toUpperCase()) {
      case 'ONLINE':
        _presenceStateController.add(ParentPresenceState.online);
        break;
      case 'READY':
        _presenceStateController.add(ParentPresenceState.ready);
        break;
      case 'MIRRORING':
        _presenceStateController.add(ParentPresenceState.mirroring);
        break;
      case 'RECONNECTING':
        _presenceStateController.add(ParentPresenceState.reconnecting);
        break;
      case 'AUTHORIZATION_REQUIRED':
        _presenceStateController.add(ParentPresenceState.authorizationRequired);
        break;
      case 'OFFLINE':
      default:
        _presenceStateController.add(ParentPresenceState.offline);
        break;
    }
  }

  void dispose() {
    _sessionStateController.close();
    _presenceStateController.close();
  }
}
