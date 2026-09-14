import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/enums.dart';
import '../lib/services/signaling_service.dart';
import '../lib/services/session_service.dart';
import '../lib/services/webrtc_service.dart';
import '../lib/services/screen_capture_service.dart';
import '../lib/services/device_service.dart';

class MockSignalingService implements SignalingService {
  final StreamController<SignalingMessage> _controller = StreamController<SignalingMessage>.broadcast();
  final List<SignalingMessage> sentMessages = [];

  @override
  Stream<SignalingMessage> get onMessage => _controller.stream;

  @override
  Stream<bool> get onConnectionStatus => Stream.value(true);

  @override
  Future<void> connect({required String deviceId, required String authToken}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> sendMessage(SignalingMessage message) async {
    sentMessages.add(message);
  }

  void emitIncoming(SignalingMessage msg) {
    _controller.add(msg);
  }
}

class MockWebRTCService extends WebRTCService {
  final StreamController<MirrorSessionState> mockState = StreamController<MirrorSessionState>.broadcast();

  @override
  Stream<MirrorSessionState> get onStateChange => mockState.stream;

  @override
  Future<void> initializePeerConnection({required bool isSender}) async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  group('Remote Screen Mirroring Protocol Tests', () {
    late MockSignalingService mockSignaling;
    late MockWebRTCService mockWebRTC;
    late ScreenCaptureService captureService;
    late DeviceService deviceService;
    late SessionService sessionService;

    setUp(() {
      mockSignaling = MockSignalingService();
      mockWebRTC = MockWebRTCService();
      captureService = ScreenCaptureService();
      deviceService = DeviceService();

      sessionService = SessionService(
        signalingService: mockSignaling,
        webRTCService: mockWebRTC,
        screenCaptureService: captureService,
        deviceService: deviceService,
      )..initialize();
    });

    tearDown(() {
      sessionService.dispose();
    });

    test('Parent initiates mirroring session sends session_request signaling', () async {
      expect(sessionService.sessionState, MirrorSessionState.idle);

      await sessionService.requestSession(childDeviceId: 'child_device_001');

      expect(sessionService.sessionState, MirrorSessionState.requested);
      expect(mockSignaling.sentMessages.length, 1);
      expect(mockSignaling.sentMessages.first.type, 'session_request');
      expect(mockSignaling.sentMessages.first.recipientId, 'child_device_001');
    });

    test('Child receives session_request and transitions to requested state', () async {
      final requestMsg = SignalingMessage(
        type: 'session_request',
        sessionId: 'sess_999',
        senderId: 'parent_admin',
        recipientId: 'child_device_001',
        data: {'quality': 'normalNetwork'},
      );

      mockSignaling.emitIncoming(requestMsg);

      await Future.delayed(const Duration(milliseconds: 20));
      expect(sessionService.sessionState, MirrorSessionState.requested);
      expect(sessionService.activeSessionId, 'sess_999');
    });

    test('Child rejects session sends decline response to parent', () async {
      await sessionService.rejectSession('sess_999', 'parent_admin', reason: 'User declined');

      expect(sessionService.sessionState, MirrorSessionState.idle);
      expect(mockSignaling.sentMessages.any((m) => m.type == 'session_response' && m.data['accepted'] == false), isTrue);
    });

    test('Session termination releases resources and notifies remote peer', () async {
      await sessionService.requestSession(childDeviceId: 'child_device_001');
      await sessionService.stopSession();

      expect(sessionService.sessionState, MirrorSessionState.ended);
      expect(mockSignaling.sentMessages.any((m) => m.type == 'session_end'), isTrue);
    });

    test('WebRTC connection state transition updates session and device status', () async {
      final states = <MirrorSessionState>[];
      sessionService.onSessionStateChanged.listen(states.add);

      mockWebRTC.mockState.add(MirrorSessionState.connecting);
      mockWebRTC.mockState.add(MirrorSessionState.connected);

      await Future.delayed(const Duration(milliseconds: 30));

      expect(states, contains(MirrorSessionState.connecting));
      expect(states, contains(MirrorSessionState.connected));
      expect(deviceService.currentStatus, DeviceStatus.mirroring);
    });
  });
}
