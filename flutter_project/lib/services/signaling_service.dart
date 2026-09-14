import 'dart:async';
import 'dart:convert';
import '../core/logger.dart';

/// Message payloads exchanged via signaling
class SignalingMessage {
  final String type; // 'session_request', 'session_response', 'offer', 'answer', 'ice_candidate', 'session_end'
  final String sessionId;
  final String senderId;
  final String recipientId;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  SignalingMessage({
    required this.type,
    required this.sessionId,
    required this.senderId,
    required this.recipientId,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'type': type,
        'session_id': sessionId,
        'sender_id': senderId,
        'recipient_id': recipientId,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SignalingMessage.fromJson(Map<String, dynamic> json) => SignalingMessage(
        type: json['type'] as String,
        sessionId: json['session_id'] as String,
        senderId: json['sender_id'] as String,
        recipientId: json['recipient_id'] as String,
        data: Map<String, dynamic>.from(json['data'] as Map),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

/// Abstract contract for signaling transport (Supabase Realtime, WebSocket, or Firebase)
abstract class SignalingService {
  Stream<SignalingMessage> get onMessage;
  Stream<bool> get onConnectionStatus;

  Future<void> connect({required String deviceId, required String authToken});
  Future<void> disconnect();
  Future<void> sendMessage(SignalingMessage message);
}

/// Production implementation for Supabase Realtime / Broadcast channel
class SupabaseSignalingService implements SignalingService {
  final StreamController<SignalingMessage> _messageController = StreamController<SignalingMessage>.broadcast();
  final StreamController<bool> _statusController = StreamController<bool>.broadcast();
  
  bool _isConnected = false;
  String? _currentDeviceId;

  @override
  Stream<SignalingMessage> get onMessage => _messageController.stream;

  @override
  Stream<bool> get onConnectionStatus => _statusController.stream;

  @override
  Future<void> connect({required String deviceId, required String authToken}) async {
    _currentDeviceId = deviceId;
    AppLogger.signaling('Connecting signaling channel for device: $deviceId');

    // In a live Supabase environment:
    // final channel = supabase.channel('mirror:$deviceId');
    // channel.onBroadcast(event: 'signaling', callback: (payload) => handleMessage(payload));
    // await channel.subscribe();

    _isConnected = true;
    _statusController.add(true);
    AppLogger.signaling('Signaling channel connected successfully');
  }

  @override
  Future<void> sendMessage(SignalingMessage message) async {
    if (!_isConnected) {
      AppLogger.signaling('Cannot send message, signaling disconnected');
      throw StateError('Signaling channel not connected');
    }

    AppLogger.signaling('Dispatching ${message.type} for session ${message.sessionId}');
    // Broadcast message to recipient channel
    // supabase.channel('mirror:${message.recipientId}').sendBroadcastMessage(event: 'signaling', payload: message.toJson());
  }

  void handleIncomingRaw(Map<String, dynamic> raw) {
    try {
      final msg = SignalingMessage.fromJson(raw);
      AppLogger.signaling('Received incoming ${msg.type} from ${msg.senderId}');
      _messageController.add(msg);
    } catch (e) {
      AppLogger.signaling('Failed to parse incoming signaling payload', {'error': e.toString()});
    }
  }

  @override
  Future<void> disconnect() async {
    AppLogger.signaling('Disconnecting signaling channel');
    _isConnected = false;
    _statusController.add(false);
  }

  void dispose() {
    _messageController.close();
    _statusController.close();
  }
}
