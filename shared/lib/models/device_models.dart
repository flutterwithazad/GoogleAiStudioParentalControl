import '../enums.dart';

class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final String? pairedParentId;
  final String? pairedParentName;
  final String androidVersion;
  final String manufacturer;
  final String model;
  final bool isBatteryOptimized;
  final DateTime registeredAt;

  DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    this.pairedParentId,
    this.pairedParentName,
    required this.androidVersion,
    required this.manufacturer,
    required this.model,
    this.isBatteryOptimized = false,
    DateTime? registeredAt,
  }) : registeredAt = registeredAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'pairedParentId': pairedParentId,
        'pairedParentName': pairedParentName,
        'androidVersion': androidVersion,
        'manufacturer': manufacturer,
        'model': model,
        'isBatteryOptimized': isBatteryOptimized,
        'registeredAt': registeredAt.toIso8601String(),
      };

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
        deviceId: json['deviceId'] as String,
        deviceName: json['deviceName'] as String,
        pairedParentId: json['pairedParentId'] as String?,
        pairedParentName: json['pairedParentName'] as String?,
        androidVersion: json['androidVersion'] as String? ?? 'Android 14',
        manufacturer: json['manufacturer'] as String? ?? 'Samsung',
        model: json['model'] as String? ?? 'SM-A546B',
        isBatteryOptimized: json['isBatteryOptimized'] as bool? ?? false,
        registeredAt: json['registeredAt'] != null
            ? DateTime.tryParse(json['registeredAt'] as String)
            : null,
      );
}

class PairingCode {
  final String code;
  final String childDeviceId;
  final String childDeviceName;
  final DateTime expiresAt;

  PairingCode({
    required this.code,
    required this.childDeviceId,
    required this.childDeviceName,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'code': code,
        'childDeviceId': childDeviceId,
        'childDeviceName': childDeviceName,
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory PairingCode.fromJson(Map<String, dynamic> json) => PairingCode(
        code: json['code'] as String,
        childDeviceId: json['childDeviceId'] as String,
        childDeviceName: json['childDeviceName'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
}

class MirrorSession {
  final String sessionId;
  final String parentId;
  final String childDeviceId;
  final MirrorSessionState state;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;

  MirrorSession({
    required this.sessionId,
    required this.parentId,
    required this.childDeviceId,
    required this.state,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'parentId': parentId,
        'childDeviceId': childDeviceId,
        'state': state.name,
        'createdAt': createdAt.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
      };
}
