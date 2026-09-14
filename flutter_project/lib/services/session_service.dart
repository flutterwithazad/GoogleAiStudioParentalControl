import 'dart:async';
import '../core/enums.dart';
import '../core/logger.dart';
import 'signaling_service.dart';
import 'webrtc_service.dart';
import 'screen_capture_service.dart';
import 'device_service.dart';

class SessionService {
  final SignalingService _signalingService;
  final WebRTCService _webRTCService;
  final ScreenCaptureService _screenCaptureService;
  final DeviceService _deviceService;

  MirrorSessionState _sessionState = MirrorSessionState.idle;
  String? _activeSessionId;
  String? _remotePeerId;
  StreamSubscription? _signalingSubscription;
  StreamSubscription? _webrtcStateSubscription;
  StreamSubscription? _nativeStateSubscription;
  StreamSubscription? _networkChangeSubscription;

  final StreamController<MirrorSessionState> _stateController = StreamController<MirrorSessionState>.broadcast();
  final StreamController<String> _errorController = StreamController<String>.broadcast();

  Stream<MirrorSessionState> get onSessionStateChanged => _stateController.stream;
  Stream<String> get onError => _errorController.stream;
  MirrorSessionState get sessionState => _sessionState;
  String? get activeSessionId => _activeSessionId;

  SessionService({
    required SignalingService signalingService,
    required WebRTCService webRTCService,
    required ScreenCaptureService screenCaptureService,
    required DeviceService deviceService,
  })  : _signalingService = signalingService,
        _webRTCService = webRTCService,
        _screenCaptureService = screenCaptureService,
        _deviceService = deviceService;

  void initialize() {
    _signalingSubscription = _signalingService.onMessage.listen(_handleSignalingMessage);
    _webrtcStateSubscription = _webRTCService.onStateChange.listen(_handleWebRTCStateChange);
    _screenCaptureService.initialize();

    // Listen to native Android state machine
    _nativeStateSubscription = _screenCaptureService.onNativeStateChanged.listen((nativeState) {
      AppLogger.session('Received native state machine update: ${nativeState.name}');
      if (nativeState == NativeSessionState.streaming) {
        _updateState(MirrorSessionState.connected);
      } else if (nativeState == NativeSessionState.reconnecting) {
        _updateState(MirrorSessionState.reconnecting);
      } else if (nativeState == NativeSessionState.reauthorizationRequired) {
        _updateState(MirrorSessionState.failed);
        _errorController.add('MediaProjection re-authorization required (Android 14+ token expired)');
      } else if (nativeState == NativeSessionState.revoked) {
        _updateState(MirrorSessionState.ended);
        _errorController.add('Screen recording permission revoked by Android system');
      }
    });

    // Listen to native network change for seamless ICE restart (Wi-Fi ↔ 4G/5G)
    _networkChangeSubscription = _screenCaptureService.onNetworkChanged.listen((netChange) async {
      AppLogger.webrtc('Network transition detected (${netChange['previous']} -> ${netChange['current']}). Initiating ICE restart...');
      if (_sessionState == MirrorSessionState.connected && _activeSessionId != null && _remotePeerId != null) {
        _updateState(MirrorSessionState.reconnecting);
        final iceRestartOffer = await _webRTCService.restartIce();
        await _signalingService.sendMessage(SignalingMessage(
          type: 'ice_restart',
          sessionId: _activeSessionId!,
          senderId: _deviceService.deviceInfo?.deviceId ?? 'child_device',
          recipientId: _remotePeerId!,
          data: {'sdp': iceRestartOffer.sdp, 'type': iceRestartOffer.type},
        ));
      }
    });
  }

  // ==========================================
  // PARENT ACTIONS
  // ==========================================

  /// Initiates a mirroring session from Parent to Child device
  Future<void> requestSession({required String childDeviceId}) async {
    _activeSessionId = 'sess_${DateTime.now().millisecondsSinceEpoch}';
    _remotePeerId = childDeviceId;
    _updateState(MirrorSessionState.requested);

    AppLogger.session('Parent requesting screen session $_activeSessionId with Child: $childDeviceId');

    await _signalingService.sendMessage(SignalingMessage(
      type: 'session_request',
      sessionId: _activeSessionId!,
      senderId: _deviceService.deviceInfo?.deviceId ?? 'parent_admin',
      recipientId: childDeviceId,
      data: {
        'requested_at': DateTime.now().toIso8601String(),
        'quality': QualityProfile.normalNetwork.name,
      },
    ));
  }

  // ==========================================
  // CHILD ACTIONS
  // ==========================================

  /// Handles incoming request on Child device, requests Android MediaProjection consent, and starts capture
  Future<bool> acceptIncomingSession(String sessionId, String parentId) async {
    _activeSessionId = sessionId;
    _remotePeerId = parentId;
    AppLogger.session('Child accepted incoming session $sessionId from Parent $parentId');

    _updateState(MirrorSessionState.connecting);

    // 1. Trigger legitimate Android MediaProjection system consent prompt
    final resultCode = await _screenCaptureService.requestMediaProjectionPermission();
    if (resultCode == null || resultCode == 0) {
      AppLogger.mediaProjection('MediaProjection consent was denied or dismissed by child');
      await rejectSession(sessionId, parentId, reason: 'MediaProjection permission denied by user');
      _updateState(MirrorSessionState.failed);
      return false;
    }

    // 2. Start Android Foreground Service with type mediaProjection
    final captureResult = await _screenCaptureService.startForegroundCapture(
      resultCode: resultCode,
      sessionId: sessionId,
      profile: QualityProfile.normalNetwork,
    );

    if (captureResult == null) {
      AppLogger.foregroundService('Failed to start native Foreground Service');
      await rejectSession(sessionId, parentId, reason: 'Foreground service startup failed');
      _updateState(MirrorSessionState.failed);
      return false;
    }

    // 3. Initialize WebRTC PeerConnection as Sender
    await _webRTCService.initializePeerConnection(isSender: true);

    // 4. Create WebRTC SDP Offer and send via Signaling
    final offer = await _webRTCService.createOffer();
    await _signalingService.sendMessage(SignalingMessage(
      type: 'offer',
      sessionId: sessionId,
      senderId: _deviceService.deviceInfo?.deviceId ?? 'child_device',
      recipientId: parentId,
      data: {
        'sdp': offer.sdp,
        'type': offer.type,
      },
    ));

    _deviceService.updateStatus(DeviceStatus.mirroring);
    return true;
  }

  Future<void> rejectSession(String sessionId, String parentId, {required String reason}) async {
    AppLogger.session('Rejecting session $sessionId. Reason: $reason');
    await _signalingService.sendMessage(SignalingMessage(
      type: 'session_response',
      sessionId: sessionId,
      senderId: _deviceService.deviceInfo?.deviceId ?? 'child_device',
      recipientId: parentId,
      data: {'accepted': false, 'reason': reason},
    ));
    _updateState(MirrorSessionState.idle);
  }

  /// Terminates mirroring session cleanly from either Child or Parent
  Future<void> stopSession() async {
    AppLogger.session('Terminating mirroring session: $_activeSessionId');
    if (_activeSessionId != null && _remotePeerId != null) {
      try {
        await _signalingService.sendMessage(SignalingMessage(
          type: 'session_end',
          sessionId: _activeSessionId!,
          senderId: _deviceService.deviceInfo?.deviceId ?? 'local',
          recipientId: _remotePeerId!,
          data: {'ended_at': DateTime.now().toIso8601String()},
        ));
      } catch (_) {}
    }

    await _screenCaptureService.stopCapture();
    await _webRTCService.dispose();
    _deviceService.updateStatus(DeviceStatus.ready);
    _updateState(MirrorSessionState.ended);
    _activeSessionId = null;
    _remotePeerId = null;
  }

  void _handleSignalingMessage(SignalingMessage msg) async {
    AppLogger.signaling('Handling signaling message: ${msg.type}');
    switch (msg.type) {
      case 'session_request':
        _activeSessionId = msg.sessionId;
        _remotePeerId = msg.senderId;
        _updateState(MirrorSessionState.requested);
        break;

      case 'session_response':
        final accepted = msg.data['accepted'] as bool? ?? false;
        if (!accepted) {
          final reason = msg.data['reason'] ?? 'Declined';
          AppLogger.session('Child declined session request: $reason');
          _errorController.add('Child device rejected session: $reason');
          _updateState(MirrorSessionState.failed);
        }
        break;

      case 'offer':
        await _webRTCService.initializePeerConnection(isSender: false);
        _updateState(MirrorSessionState.connecting);
        break;

      case 'session_end':
        AppLogger.session('Remote peer ended the mirroring session');
        await stopSession();
        break;
    }
  }

  void _handleWebRTCStateChange(MirrorSessionState state) {
    _updateState(state);
    if (state == MirrorSessionState.connected) {
      _deviceService.updateStatus(DeviceStatus.mirroring);
    } else if (state == MirrorSessionState.ended || state == MirrorSessionState.failed) {
      _deviceService.updateStatus(DeviceStatus.ready);
    }
  }

  void _updateState(MirrorSessionState newState) {
    if (_sessionState != newState) {
      _sessionState = newState;
      AppLogger.session('MirrorSessionState transition -> ${newState.name}');
      _stateController.add(newState);
    }
  }

  void dispose() {
    _signalingSubscription?.cancel();
    _webrtcStateSubscription?.cancel();
    _nativeStateSubscription?.cancel();
    _networkChangeSubscription?.cancel();
    _stateController.close();
    _errorController.close();
  }
}
