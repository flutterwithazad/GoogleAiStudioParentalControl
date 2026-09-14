import 'dart:async';
import 'package:flutter/services.dart';
import '../core/enums.dart';
import '../core/logger.dart';

class ScreenCaptureResult {
  final int width;
  final int height;
  final int fps;
  final int bitrateKbps;

  ScreenCaptureResult({
    required this.width,
    required this.height,
    required this.fps,
    required this.bitrateKbps,
  });
}

class ScreenCaptureService {
  static const MethodChannel _methodChannel = MethodChannel('com.parental.screenmirror/capture');
  static const EventChannel _eventChannel = EventChannel('com.parental.screenmirror/events');

  final StreamController<DeviceStatus> _statusController = StreamController<DeviceStatus>.broadcast();
  final StreamController<NativeSessionState> _nativeStateController = StreamController<NativeSessionState>.broadcast();
  final StreamController<Map<String, String>> _networkChangeController = StreamController<Map<String, String>>.broadcast();
  final StreamController<Map<String, dynamic>> _errorController = StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription? _eventSubscription;
  Completer<int?>? _permissionCompleter;
  NativeSessionState _currentNativeState = NativeSessionState.idle;

  Stream<DeviceStatus> get onStatusChanged => _statusController.stream;
  Stream<NativeSessionState> get onNativeStateChanged => _nativeStateController.stream;
  Stream<Map<String, String>> get onNetworkChanged => _networkChangeController.stream;
  Stream<Map<String, dynamic>> get onError => _errorController.stream;
  NativeSessionState get currentNativeState => _currentNativeState;

  void initialize() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          final type = event['type'];
          if (type == 'STATE_CHANGED') {
            final stateStr = event['state'] as String? ?? 'IDLE';
            final nativeState = NativeSessionState.fromString(stateStr);
            _currentNativeState = nativeState;
            AppLogger.foregroundService('Native service state: ${nativeState.toDisplayString()}');
            _nativeStateController.add(nativeState);

            if (nativeState == NativeSessionState.streaming || nativeState == NativeSessionState.capturing) {
              _statusController.add(DeviceStatus.mirroring);
            } else if (nativeState == NativeSessionState.stopped || nativeState == NativeSessionState.idle) {
              _statusController.add(DeviceStatus.ready);
            } else if (nativeState == NativeSessionState.error || nativeState == NativeSessionState.revoked) {
              _statusController.add(DeviceStatus.error);
            }
          } else if (type == 'NETWORK_CHANGED') {
            final prev = event['previousType'] as String? ?? '';
            final curr = event['currentType'] as String? ?? '';
            AppLogger.webrtc('Network transition: $prev -> $curr');
            _networkChangeController.add({'previous': prev, 'current': curr});
          } else if (type == 'PERMISSION_RESULT') {
            final granted = event['granted'] as bool? ?? false;
            final resultCode = event['resultCode'] as int? ?? 0;
            AppLogger.mediaProjection('Permission result: granted=$granted, resultCode=$resultCode');
            if (_permissionCompleter != null && !_permissionCompleter!.isCompleted) {
              _permissionCompleter!.complete(granted ? resultCode : null);
            }
          } else if (type == 'ERROR') {
            final code = event['code'] as String;
            final msg = event['message'] as String;
            AppLogger.mediaProjection('Native capture error [$code]: $msg');
            _errorController.add({'code': code, 'message': msg});
            _statusController.add(DeviceStatus.error);
          }
        }
      },
      onError: (err) {
        AppLogger.foregroundService('EventChannel error: $err');
      },
    );
  }

  /// Query native state independently of memory cache
  Future<NativeSessionState> getNativeState() async {
    try {
      final stateStr = await _methodChannel.invokeMethod<String>('getNativeState');
      if (stateStr != null) {
        _currentNativeState = NativeSessionState.fromString(stateStr);
        return _currentNativeState;
      }
    } catch (_) {}
    return NativeSessionState.idle;
  }

  /// Triggers the Android system MediaProjection dialog via MainActivity
  Future<int?> requestMediaProjectionPermission() async {
    AppLogger.mediaProjection('Requesting system MediaProjection consent dialog');
    _permissionCompleter = Completer<int?>();
    try {
      await _methodChannel.invokeMethod('requestProjectionPermission');
      return await _permissionCompleter!.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          AppLogger.mediaProjection('MediaProjection consent timed out or was dismissed');
          return null;
        },
      );
    } on PlatformException catch (e) {
      AppLogger.mediaProjection('Failed to request projection: ${e.message}');
      return null;
    }
  }

  /// Starts the Android Foreground Service with FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
  Future<ScreenCaptureResult?> startForegroundCapture({
    required int resultCode,
    String? sessionId,
    QualityProfile profile = QualityProfile.normalNetwork,
  }) async {
    AppLogger.foregroundService('Starting native foreground capture with profile: ${profile.name}');
    try {
      final res = await _methodChannel.invokeMethod<Map>('startForegroundCapture', {
        'resultCode': resultCode,
        'sessionId': sessionId,
        'profile': profile.name.toUpperCase(),
      });

      if (res != null) {
        return ScreenCaptureResult(
          width: res['width'] as int? ?? profile.width,
          height: res['height'] as int? ?? profile.height,
          fps: res['fps'] as int? ?? profile.fps,
          bitrateKbps: res['bitrate'] as int? ?? profile.bitrateKbps,
        );
      }
      return null;
    } on PlatformException catch (e) {
      AppLogger.foregroundService('Failed to start native capture service: ${e.message}');
      _statusController.add(DeviceStatus.error);
      return null;
    }
  }

  /// Stops Foreground Service and releases MediaProjection + VirtualDisplay
  Future<bool> stopCapture() async {
    AppLogger.foregroundService('Invoking native stopCapture');
    try {
      await _methodChannel.invokeMethod('stopCapture');
      _statusController.add(DeviceStatus.stopped);
      return true;
    } on PlatformException catch (e) {
      AppLogger.foregroundService('Error stopping capture service: ${e.message}');
      return false;
    }
  }

  Future<bool> isCapturing() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('isCapturing');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Persists safe pairing info into native SharedPreferences for BootReceiver & NativeSignaling
  Future<void> savePairingToNative({
    required String deviceId,
    required String deviceName,
    required String parentId,
    required String parentName,
    required String endpoint,
  }) async {
    try {
      await _methodChannel.invokeMethod('savePairing', {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'parentId': parentId,
        'parentName': parentName,
        'endpoint': endpoint,
      });
    } catch (e) {
      AppLogger.foregroundService('Failed to save pairing to native: $e');
    }
  }

  Future<void> clearPairingInNative() async {
    try {
      await _methodChannel.invokeMethod('clearPairing');
    } catch (_) {}
  }

  // Battery Optimization & OEM Methods
  Future<bool> isBatteryOptimizationIgnored() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('isBatteryOptimizationIgnored');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestIgnoreBatteryOptimization() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('requestIgnoreBatteryOptimization');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isAggressiveOem() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('isAggressiveOem');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String> getOemManufacturer() async {
    try {
      final res = await _methodChannel.invokeMethod<String>('getOemManufacturer');
      return res ?? 'android';
    } catch (_) {
      return 'android';
    }
  }

  Future<bool> openOemBatterySettings() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('openOemBatterySettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _eventSubscription?.cancel();
    _statusController.close();
    _nativeStateController.close();
    _networkChangeController.close();
    _errorController.close();
  }
}
