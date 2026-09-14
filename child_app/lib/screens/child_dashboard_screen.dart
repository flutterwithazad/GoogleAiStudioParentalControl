import 'package:flutter/material.dart';
import 'package:screen_mirror_shared/enums.dart';
import '../services/child_platform_bridge.dart';

class ChildDashboardScreen extends StatefulWidget {
  final ChildPlatformBridge platformBridge;

  const ChildDashboardScreen({
    super.key,
    required this.platformBridge,
  });

  @override
  State<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends State<ChildDashboardScreen> {
  NativeSessionState _currentState = NativeSessionState.ready;
  bool _isExempt = false;
  Map<String, dynamic> _stats = {'fps': 30, 'bitrate': 1450, 'width': 1280, 'height': 720};

  @override
  void initState() {
    super.initState();
    _checkInitialState();
    _bindEvents();
  }

  Future<void> _checkInitialState() async {
    final state = await widget.platformBridge.getCaptureState();
    final exempt = await widget.platformBridge.checkBatteryOptimization();
    if (mounted) {
      setState(() {
        _currentState = state;
        _isExempt = exempt;
      });
    }
  }

  void _bindEvents() {
    widget.platformBridge.onNativeEvent.listen((event) {
      final type = event['type'] as String?;
      if (mounted) {
        setState(() {
          if (type == 'captureStarted' || event['state'] == 'CAPTURING') {
            _currentState = NativeSessionState.capturing;
          } else if (type == 'captureStopped' || event['state'] == 'READY') {
            _currentState = NativeSessionState.ready;
          } else if (type == 'captureRevoked') {
            _currentState = NativeSessionState.revoked;
          } else if (type == 'stateChanged') {
            final stateStr = event['state'] as String?;
            if (stateStr != null) {
              _currentState = _parseState(stateStr);
            }
          }
        });
      }
    });
  }

  NativeSessionState _parseState(String stateStr) {
    switch (stateStr.toUpperCase()) {
      case 'STREAMING':
        return NativeSessionState.streaming;
      case 'CAPTURING':
        return NativeSessionState.capturing;
      case 'CONNECTING':
        return NativeSessionState.connecting;
      case 'RECONNECTING':
        return NativeSessionState.reconnecting;
      case 'REAUTHORIZATION_REQUIRED':
        return NativeSessionState.reauthorizationRequired;
      case 'REVOKED':
        return NativeSessionState.revoked;
      case 'READY':
      default:
        return NativeSessionState.ready;
    }
  }

  Color _getStatusColor() {
    switch (_currentState) {
      case NativeSessionState.capturing:
      case NativeSessionState.streaming:
        return const Color(0xFFDC2626); // Red alert for active capture
      case NativeSessionState.connecting:
      case NativeSessionState.starting:
        return const Color(0xFFF59E0B);
      case NativeSessionState.ready:
        return const Color(0xFF10B981);
      case NativeSessionState.reauthorizationRequired:
        return const Color(0xFFEA580C);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCapturing = (_currentState == NativeSessionState.capturing ||
        _currentState == NativeSessionState.streaming);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Child Device', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Device Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor().withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _getStatusColor(),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _currentState.toDisplayString().toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Paired Parent: parent_admin_uuid',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Native Foreground Service: REGISTERED',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                  const Divider(height: 28, color: Color(0xFFE5E7EB)),

                  // MediaProjection Transparency Notice
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isCapturing ? Icons.videocam : Icons.security,
                        size: 20,
                        color: isCapturing ? const Color(0xFFDC2626) : const Color(0xFF4B5563),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isCapturing
                              ? 'Screen mirroring is currently active. The Android OS displays a mandatory privacy indicator in the status bar and an ongoing foreground notification.'
                              : 'Ready for parent viewing requests. When active, an Android system notification and recording chip will be visible at all times.',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Battery Optimization Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isExempt ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isExempt ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isExempt ? Icons.battery_charging_full : Icons.battery_alert,
                    color: _isExempt ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isExempt
                              ? 'Unrestricted Battery Usage: ACTIVE'
                              : 'Battery Exemption Recommended',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _isExempt ? const Color(0xFF166534) : const Color(0xFF991B1B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isExempt
                              ? 'The native capture service will continue if app is closed or removed from Recents.'
                              : 'Prevents Android OEM task killers from terminating active screen mirroring.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _isExempt ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isExempt)
                    TextButton(
                      onPressed: () async {
                        await widget.platformBridge.requestBatteryOptimizationExemption();
                        final exempt = await widget.platformBridge.checkBatteryOptimization();
                        if (mounted) setState(() => _isExempt = exempt);
                      },
                      child: const Text('Exempt'),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // OEM Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Android 14+ Persistence Architecture',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Native Foreground Service operates independently from Flutter Activity.\n'
                    '• Service specifies stopWithTask="false" to survive swipe from Recents.\n'
                    '• Android 14 MediaProjection consent token is ephemeral and single-use.\n'
                    '• If process is killed by OS LMK, re-authorization is legally required by Android security policy.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF4B5563), height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => widget.platformBridge.openOemBatterySettings(),
                    child: const Text('Check OEM Background Settings'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Action Buttons
            if (!isCapturing)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await widget.platformBridge.startScreenCapture(
                      sessionId: 'sess_${DateTime.now().millisecondsSinceEpoch}',
                      parentId: 'parent_admin_uuid',
                    );
                  },
                  child: const Text(
                    'Test Capture Consent Flow',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await widget.platformBridge.stopScreenCapture();
                  },
                  child: const Text(
                    'Stop Native Capture',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
