import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../core/enums.dart';
import '../core/logger.dart';

class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final String manufacturer;
  final String model;
  final int androidSdkVersion;
  final String? pairedParentName;
  final String? pairedParentId;

  DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.manufacturer,
    required this.model,
    required this.androidSdkVersion,
    this.pairedParentName,
    this.pairedParentId,
  });
}

class DeviceService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  DeviceStatus _currentStatus = DeviceStatus.deviceNotConfigured;
  DeviceInfo? _deviceInfo;

  final StreamController<DeviceStatus> _statusStreamController = StreamController<DeviceStatus>.broadcast();
  Stream<DeviceStatus> get onStatusChanged => _statusStreamController.stream;
  DeviceStatus get currentStatus => _currentStatus;
  DeviceInfo? get deviceInfo => _deviceInfo;

  Future<void> initialize() async {
    AppLogger.screenCapture('Initializing DeviceService');
    await _loadDeviceInfo();
    await _loadPersistedStatus();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final androidInfo = await _deviceInfoPlugin.androidInfo;
      final savedDeviceId = await _storage.read(key: 'device_id');
      final deviceId = savedDeviceId ?? 'child_${androidInfo.id.substring(0, 8)}';
      if (savedDeviceId == null) {
        await _storage.write(key: 'device_id', value: deviceId);
      }

      final parentName = await _storage.read(key: 'paired_parent_name');
      final parentId = await _storage.read(key: 'paired_parent_id');

      _deviceInfo = DeviceInfo(
        deviceId: deviceId,
        deviceName: '${androidInfo.brand.toUpperCase()} ${androidInfo.model}',
        manufacturer: androidInfo.manufacturer,
        model: androidInfo.model,
        androidSdkVersion: androidInfo.version.sdkInt,
        pairedParentName: parentName,
        pairedParentId: parentId,
      );

      AppLogger.screenCapture('Device detected: ${_deviceInfo!.deviceName} (Android API ${_deviceInfo!.androidSdkVersion})');
    } catch (e) {
      AppLogger.screenCapture('Failed to read device info', {'error': e.toString()});
    }
  }

  Future<void> _loadPersistedStatus() async {
    final configured = await _storage.read(key: 'is_configured') == 'true';
    if (configured && _deviceInfo?.pairedParentId != null) {
      updateStatus(DeviceStatus.ready);
    } else if (configured) {
      updateStatus(DeviceStatus.deviceConfigured);
    } else {
      updateStatus(DeviceStatus.deviceNotConfigured);
    }
  }

  void updateStatus(DeviceStatus newStatus) {
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      AppLogger.session('DeviceStatus transition -> ${newStatus.name}');
      _statusStreamController.add(newStatus);
    }
  }

  Future<void> savePairing({required String parentId, required String parentName}) async {
    await _storage.write(key: 'paired_parent_id', value: parentId);
    await _storage.write(key: 'paired_parent_name', value: parentName);
    await _storage.write(key: 'is_configured', value: 'true');
    await _loadDeviceInfo();
    updateStatus(DeviceStatus.ready);
  }

  Future<void> unpair() async {
    await _storage.delete(key: 'paired_parent_id');
    await _storage.delete(key: 'paired_parent_name');
    await _storage.write(key: 'is_configured', value: 'false');
    await _loadDeviceInfo();
    updateStatus(DeviceStatus.deviceNotConfigured);
  }

  void dispose() {
    _statusStreamController.close();
  }
}
