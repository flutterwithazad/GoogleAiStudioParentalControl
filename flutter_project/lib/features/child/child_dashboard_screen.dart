import 'package:flutter/material.dart';
import '../../core/enums.dart';
import '../../services/device_service.dart';
import '../../services/session_service.dart';
import '../../services/screen_capture_service.dart';

class ChildDashboardScreen extends StatefulWidget {
  final DeviceService deviceService;
  final SessionService sessionService;
  final ScreenCaptureService screenCaptureService;
  final VoidCallback onOpenSetup;

  const ChildDashboardScreen({
    super.key,
    required this.deviceService,
    required this.sessionService,
    required this.screenCaptureService,
    required this.onOpenSetup,
  });

  @override
  State<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends State<ChildDashboardScreen> {
  DeviceStatus _status = DeviceStatus.ready;
  MirrorSessionState _sessionState = MirrorSessionState.idle;
  NativeSessionState _nativeState = NativeSessionState.idle;
  bool _isBatteryOptimized = false;
  bool _isAggressiveOem = false;
  String _oemManufacturer = '';

  @override
  void initState() {
    super.initState();
    _status = widget.deviceService.currentStatus;
    _listenStatus();
    _checkBatteryAndOem();
    _syncPairingToNative();
  }

  Future<void> _checkBatteryAndOem() async {
    final ignored = await widget.screenCaptureService.isBatteryOptimizationIgnored();
    final oemAggressive = await widget.screenCaptureService.isAggressiveOem();
    final mfg = await widget.screenCaptureService.getOemManufacturer();
    if (mounted) {
      setState(() {
        _isBatteryOptimized = ignored;
        _isAggressiveOem = oemAggressive;
        _oemManufacturer = mfg;
      });
    }
  }

  Future<void> _syncPairingToNative() async {
    final info = widget.deviceService.deviceInfo;
    if (info != null) {
      await widget.screenCaptureService.savePairingToNative(
        deviceId: info.deviceId,
        deviceName: info.deviceName,
        parentId: info.pairedParentId ?? 'parent_admin',
        parentName: info.pairedParentName ?? 'Parent',
        endpoint: 'https://signal.local',
      );
    }
  }

  void _listenStatus() {
    widget.deviceService.onStatusChanged.listen((s) {
      if (mounted) setState(() => _status = s);
    });

    widget.sessionService.onSessionStateChanged.listen((s) {
      if (mounted) {
        setState(() => _sessionState = s);
        if (s == MirrorSessionState.requested) {
          _showIncomingSessionDialog();
        }
      }
    });

    widget.screenCaptureService.onNativeStateChanged.listen((ns) {
      if (mounted) setState(() => _nativeState = ns);
    });
  }

  void _showIncomingSessionDialog() {
    final parentName = widget.deviceService.deviceInfo?.pairedParentName ?? 'Parent';
    final sessionId = widget.sessionService.activeSessionId ?? 'sess';
    final parentId = widget.deviceService.deviceInfo?.pairedParentId ?? 'parent';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cast, color: Color(0xFF2563EB)),
            SizedBox(width: 10),
            Text('Screen Share Request'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$parentName is requesting to view your Android screen.',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Color(0xFFB45309)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Android will ask for MediaProjection authorization to record your screen.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.sessionService.rejectSession(sessionId, parentId, reason: 'Declined by child');
            },
            child: const Text('Decline', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              widget.sessionService.acceptIncomingSession(sessionId, parentId);
            },
            child: const Text('Allow & Share'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMirroring = _status == DeviceStatus.mirroring || _nativeState == NativeSessionState.streaming;
    final parentName = widget.deviceService.deviceInfo?.pairedParentName ?? "Parent";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('ScreenMirror Child', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: widget.onOpenSetup,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Active Sharing Notice (Android compliant, cannot be hidden)
              if (isMirroring) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF3B82F6)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.screen_share, color: Color(0xFF2563EB), size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Screen Sharing is Active',
                              style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
                            ),
                            Text(
                              'Your screen is currently visible to $parentName',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF1E40AF)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Reauthorization Warning if Android 14+ token expired
              if (_nativeState == NativeSessionState.reauthorizationRequired) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEF4444)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Screen capture paused: Re-authorization required by Android OS.',
                          style: TextStyle(color: Color(0xFF991B1B), fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Card 1: Device Status & Native Lifecycle
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Device Status', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Connected',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Screen Mirroring Status
                    const Text('Native Service State', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isMirroring
                                ? Colors.blue
                                : (_nativeState == NativeSessionState.error ? Colors.red : Colors.green),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _nativeState.toDisplayString(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isMirroring ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Parent Device
                    const Text('Paired Parent Device', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                    const SizedBox(height: 8),
                    Text(
                      parentName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Battery / OEM Optimization Helper Card
              if (!_isBatteryOptimized)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.battery_alert, color: Color(0xFFF59E0B), size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Background Optimization Active',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                            ),
                            Text(
                              'Exempt app from battery saver to avoid drops when swiped away.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await widget.screenCaptureService.requestIgnoreBatteryOptimization();
                          await _checkBatteryAndOem();
                        },
                        child: const Text('Exempt', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

              const Spacer(),

              // Stop Mirroring Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMirroring ? Colors.redAccent.shade700 : const Color(0xFFE2E8F0),
                    foregroundColor: isMirroring ? Colors.white : const Color(0xFF64748B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: isMirroring ? 2 : 0,
                  ),
                  onPressed: isMirroring ? () => widget.sessionService.stopSession() : null,
                  child: const Text(
                    'Stop Mirroring',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
