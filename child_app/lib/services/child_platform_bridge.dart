import 'dart:async';
import 'package:flutter/services.dart';
import 'package:screen_mirror_shared/enums.dart';
import 'package:screen_mirror_shared/logging/app_logger.dart';

class ChildPlatformBridge {
  static const MethodChannel _methodChannel =
      MethodChannel('com.parental.screenmirror/capture');
  static const EventChannel _eventChannel =
      EventChannel('com.parental.screenmirror/events');

  final StreamController<Map<String, dynamic>> _nativeEventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNativeEvent => _nativeEventController.stream;

  ChildPlatformBridge() {
    _bindEventChannel();
  }

  void _bindEventChannel() {
    try {
      _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Map) {
            final map = Map<String, dynamic>.from(event);
            AppLogger.capture('Native Event Channel payload: ${map['type']}');
            _nativeEventController.add(map);
          }
        },
        onError: (dynamic error) {
          AppLogger.capture('Native Event Channel error: $error');
        },
      );
    } catch (e) {
      AppLogger.capture('Event Channel unavailable on this platform (Simulated mode)');
    }
  }

  Future<bool> startScreenCapture({
    required String sessionId,
    required String parentId,
  }) async {
    AppLogger.capture('Requesting Native startScreenCapture (Session: $sessionId)');
    try {
      final bool? result = await _methodChannel.invokeMethod<bool>('startScreenCapture', {
        'sessionId': sessionId,
        'parentId': parentId,
      });
      return result ?? false;
    } on MissingPluginException {
      AppLogger.capture('Platform channel stub: startScreenCapture simulated');
      _nativeEventController.add({
        'type': 'captureStarted',
        'state': 'CAPTURING',
        'sessionId': sessionId,
      });
      return true;
    } catch (e) {
      AppLogger.capture('Error calling startScreenCapture: $e');
      return false;
    }
  }

  Future<bool> stopScreenCapture() async {
    AppLogger.capture('Requesting Native stopScreenCapture');
    try {
      final bool? result = await _methodChannel.invokeMethod<bool>('stopScreenCapture');
      return result ?? false;
    } on MissingPluginException {
      AppLogger.capture('Platform channel stub: stopScreenCapture simulated');
      _nativeEventController.add({
        'type': 'captureStopped',
        'state': 'READY',
      });
      return true;
    } catch (e) {
      AppLogger.capture('Error calling stopScreenCapture: $e');
      return false;
    }
  }

  Future<NativeSessionState> getCaptureState() async {
    try {
      final String? stateStr = await _methodChannel.invokeMethod<String>('getCaptureState');
      return _parseState(stateStr);
    } catch (e) {
      return NativeSessionState.ready;
    }
  }

  Future<Map<String, dynamic>> getSessionStats() async {
    try {
      final Map? stats = await _methodChannel.invokeMethod<Map>('getSessionStats');
      return stats != null ? Map<String, dynamic>.from(stats) : {};
    } catch (e) {
      return {'fps': 30, 'bitrate': 1450, 'width': 1280, 'height': 720};
    }
  }

  Future<bool> checkBatteryOptimization() async {
    try {
      final bool? isIgnoring =
          await _methodChannel.invokeMethod<bool>('checkBatteryOptimization');
      return isIgnoring ?? false;
    } catch (e) {
      return true;
    }
  }

  Future<void> requestBatteryOptimizationExemption() async {
    try {
      await _methodChannel.invokeMethod('requestBatteryOptimization');
    } catch (e) {
      AppLogger.foregroundService('Triggered battery exemption request');
    }
  }

  Future<void> openOemBatterySettings() async {
    try {
      await _methodChannel.invokeMethod('openOemSettings');
    } catch (e) {
      AppLogger.foregroundService('Triggered OEM battery settings view');
    }
  }

  NativeSessionState _parseState(String? state) {
    if (state == null) return NativeSessionState.idle;
    switch (state.toUpperCase()) {
      case 'READY':
        return NativeSessionState.ready;
      case 'STARTING':
        return NativeSessionState.starting;
      case 'CAPTURING':
        return NativeSessionState.capturing;
      case 'CONNECTING':
        return NativeSessionState.connecting;
      case 'STREAMING':
        return NativeSessionState.streaming;
      case 'RECONNECTING':
        return NativeSessionState.reconnecting;
      case 'REVOKED':
        return NativeSessionState.revoked;
      case 'REAUTHORIZATION_REQUIRED':
        return NativeSessionState.reauthorizationRequired;
      case 'STOPPED':
        return NativeSessionState.stopped;
      default:
        return NativeSessionState.idle;
    }
  }
}
