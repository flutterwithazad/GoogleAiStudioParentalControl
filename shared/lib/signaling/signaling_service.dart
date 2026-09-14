import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../logging/app_logger.dart';

abstract class SignalingService {
  Stream<Map<String, dynamic>> get onSignalReceived;

  Future<void> connect({required String deviceId, required String authToken});
  Future<void> disconnect();

  Future<String> createSession({
    required String parentId,
    required String childDeviceId,
  });

  Future<void> sendSessionRequest({
    required String sessionId,
    required String targetDeviceId,
    required String parentId,
    required String parentName,
  });

  Future<void> sendOffer({
    required String sessionId,
    required String targetDeviceId,
    required String sdp,
  });

  Future<void> sendAnswer({
    required String sessionId,
    required String targetDeviceId,
    required String sdp,
  });

  Future<void> sendIceCandidate({
    required String sessionId,
    required String targetDeviceId,
    required Map<String, dynamic> candidate,
  });

  Future<void> endSession({
    required String sessionId,
    required String targetDeviceId,
    String? reason,
  });
}

class SupabaseSignalingService implements SignalingService {
  final SupabaseClient? _client;
  RealtimeChannel? _channel;
  final StreamController<Map<String, dynamic>> _signalController =
      StreamController<Map<String, dynamic>>.broadcast();

  String? _currentDeviceId;

  SupabaseSignalingService([this._client]);

  @override
  Stream<Map<String, dynamic>> get onSignalReceived => _signalController.stream;

  @override
  Future<void> connect({required String deviceId, required String authToken}) async {
    _currentDeviceId = deviceId;
    AppLogger.signaling('Connecting signaling channel for device: $deviceId');

    if (_client != null) {
      _channel = _client.channel('signaling:$deviceId')
        ..onBroadcast(event: 'signal', callback: (payload) {
          AppLogger.signaling('Received inbound signaling packet: ${payload['type']}');
          _signalController.add(payload);
        })
        ..subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            AppLogger.signaling('Subscribed to real-time signaling topic');
          } else if (error != null) {
            AppLogger.signaling('Signaling subscription error: $error');
          }
        });
    } else {
      AppLogger.signaling('Client not initialized; offline signaling standby');
    }
  }

  @override
  Future<void> disconnect() async {
    AppLogger.signaling('Disconnecting signaling channel');
    await _channel?.unsubscribe();
    _channel = null;
  }

  @override
  Future<String> createSession({
    required String parentId,
    required String childDeviceId,
  }) async {
    final sessionId = 'sess_${DateTime.now().millisecondsSinceEpoch}';
    AppLogger.signaling('Created session record: $sessionId ($parentId -> $childDeviceId)');

    if (_client != null) {
      await _client.from('mirroring_sessions').insert({
        'id': sessionId,
        'parent_id': parentId,
        'child_device_id': childDeviceId,
        'status': 'REQUESTED',
        'created_at': DateTime.now().toIso8601String(),
        'last_activity_at': DateTime.now().toIso8601String(),
      });
    }

    return sessionId;
  }

  @override
  Future<void> sendSessionRequest({
    required String sessionId,
    required String targetDeviceId,
    required String parentId,
    required String parentName,
  }) async {
    AppLogger.signaling('Sending session request to $targetDeviceId for session $sessionId');
    await _sendPayload(targetDeviceId, {
      'type': 'session_request',
      'session_id': sessionId,
      'parent_id': parentId,
      'parent_name': parentName,
    });
  }

  @override
  Future<void> sendOffer({
    required String sessionId,
    required String targetDeviceId,
    required String sdp,
  }) async {
    AppLogger.signaling('Sending SDP Offer to $targetDeviceId (Session: $sessionId)');
    await _sendPayload(targetDeviceId, {
      'type': 'offer',
      'sessionId': sessionId,
      'senderId': _currentDeviceId,
      'sdp': sdp,
    });
  }

  @override
  Future<void> sendAnswer({
    required String sessionId,
    required String targetDeviceId,
    required String sdp,
  }) async {
    AppLogger.signaling('Sending SDP Answer to $targetDeviceId (Session: $sessionId)');
    await _sendPayload(targetDeviceId, {
      'type': 'answer',
      'sessionId': sessionId,
      'senderId': _currentDeviceId,
      'sdp': sdp,
    });
  }

  @override
  Future<void> sendIceCandidate({
    required String sessionId,
    required String targetDeviceId,
    required Map<String, dynamic> candidate,
  }) async {
    AppLogger.signaling('Sending ICE candidate to $targetDeviceId (Session: $sessionId)');
    await _sendPayload(targetDeviceId, {
      'type': 'ice_candidate',
      'sessionId': sessionId,
      'senderId': _currentDeviceId,
      'candidate': candidate,
    });
  }

  @override
  Future<void> endSession({
    required String sessionId,
    required String targetDeviceId,
    String? reason,
  }) async {
    AppLogger.signaling('Sending session_end to $targetDeviceId (Reason: ${reason ?? "User stopped"})');
    await _sendPayload(targetDeviceId, {
      'type': 'session_end',
      'sessionId': sessionId,
      'senderId': _currentDeviceId,
      'reason': reason ?? 'User ended session',
    });

    if (_client != null) {
      await _client.from('mirroring_sessions').update({
        'status': 'ENDED',
        'ended_at': DateTime.now().toIso8601String(),
      }).eq('id', sessionId);
    }
  }

  Future<void> _sendPayload(String targetDeviceId, Map<String, dynamic> data) async {
    if (_client != null) {
      final targetChannel = _client.channel('signaling:$targetDeviceId');
      await targetChannel.sendBroadcastMessage(
        event: 'signal',
        payload: data,
      );
    } else {
      AppLogger.signaling('Standby: Broadcast queued for target: $targetDeviceId (${data['type']})');
    }
  }

  void simulateInboundSignal(Map<String, dynamic> signal) {
    _signalController.add(signal);
  }
}
