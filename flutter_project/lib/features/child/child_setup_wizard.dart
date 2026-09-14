import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/enums.dart';
import '../../services/device_service.dart';
import '../../services/screen_capture_service.dart';

class ChildSetupWizard extends StatefulWidget {
  final DeviceService deviceService;
  final ScreenCaptureService screenCaptureService;
  final VoidCallback onComplete;

  const ChildSetupWizard({
    super.key,
    required this.deviceService,
    required this.screenCaptureService,
    required this.onComplete,
  });

  @override
  State<ChildSetupWizard> createState() => _ChildSetupWizardState();
}

class _ChildSetupWizardState extends State<ChildSetupWizard> {
  int _currentStep = 0;
  bool _notificationGranted = false;
  bool _batteryOptimized = false;
  bool _projectionTested = false;

  @override
  void initState() {
    super.initState();
    _checkInitialPermissions();
  }

  Future<void> _checkInitialPermissions() async {
    final status = await Permission.notification.status;
    setState(() {
      _notificationGranted = status.isGranted;
    });
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    setState(() {
      _notificationGranted = status.isGranted;
    });
    if (status.isGranted) {
      _nextStep();
    }
  }

  Future<void> _requestBatteryOptimization() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    setState(() {
      _batteryOptimized = status.isGranted;
    });
    _nextStep();
  }

  Future<void> _testMediaProjection() async {
    final code = await widget.screenCaptureService.requestMediaProjectionPermission();
    if (code != null && code != 0) {
      setState(() {
        _projectionTested = true;
      });
      _nextStep();
    }
  }

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() => _currentStep++);
    } else {
      widget.deviceService.updateStatus(DeviceStatus.deviceConfigured);
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Child Device Setup', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: (_currentStep + 1) / 5,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildStepContent(),
                ),
              ),
              const SizedBox(height: 16),
              _buildBottomButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildIntroStep();
      case 1:
        return _buildNotificationStep();
      case 2:
        return _buildBatteryStep();
      case 3:
        return _buildMediaProjectionStep();
      case 4:
        return _buildPairingStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildIntroStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.shield_outlined, size: 48, color: Color(0xFF2563EB)),
        const SizedBox(height: 16),
        const Text(
          'How Screen Mirroring Works',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 12),
        const Text(
          'This app allows your verified parent to view your screen in real time to provide guidance and ensure safety.\n\n'
          'Important Privacy Guarantees:\n'
          '• No secret recording: A visible notification will always indicate when streaming is active.\n'
          '• No camera or microphone access: Only the display frames are mirrored.\n'
          '• You can stop sharing at any time with a single tap.',
          style: TextStyle(fontSize: 15, color: Color(0xFF334155), height: 1.6),
        ),
      ],
    );
  }

  Widget _buildNotificationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.notifications_active_outlined, size: 48, color: Color(0xFF2563EB)),
        const SizedBox(height: 16),
        const Text(
          'Notification Permission',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 12),
        const Text(
          'Android requires this permission so the app can display the mandatory Foreground Service notification while screen mirroring is active.',
          style: TextStyle(fontSize: 15, color: Color(0xFF334155), height: 1.5),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _notificationGranted ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                _notificationGranted ? Icons.check_circle : Icons.info,
                color: _notificationGranted ? Colors.green : const Color(0xFF64748B),
              ),
              const SizedBox(width: 12),
              Text(
                _notificationGranted ? 'Permission Granted' : 'Permission Required',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _notificationGranted ? Colors.green.shade800 : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBatteryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.battery_saver, size: 48, color: Color(0xFF2563EB)),
        const SizedBox(height: 16),
        const Text(
          'Background Reliability',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 12),
        const Text(
          'To ensure the mirroring stream does not abruptly disconnect when switching apps, allow this service to run without aggressive OEM battery kills.',
          style: TextStyle(fontSize: 15, color: Color(0xFF334155), height: 1.5),
        ),
      ],
    );
  }

  Widget _buildMediaProjectionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.cast_connected, size: 48, color: Color(0xFF2563EB)),
        const SizedBox(height: 16),
        const Text(
          'MediaProjection Consent Test',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 12),
        const Text(
          'Android requires explicit consent to capture display frames. On Android 14 and 15, this authorization is session-scoped for privacy.\n\n'
          'Tap "Test Screen Capture" to verify your device displays the official Android MediaProjection dialog.',
          style: TextStyle(fontSize: 15, color: Color(0xFF334155), height: 1.5),
        ),
        const SizedBox(height: 24),
        if (_projectionTested)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 12),
                Text(
                  'MediaProjection verified on this device',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green.shade800),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPairingStep() {
    final deviceId = widget.deviceService.deviceInfo?.deviceId ?? 'CHILD-8274';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.qr_code_2, size: 48, color: Color(0xFF2563EB)),
        const SizedBox(height: 16),
        const Text(
          'Ready to Pair',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 12),
        const Text(
          'Your device setup is complete. Link this device with the Parent App using the pairing code or QR code.',
          style: TextStyle(fontSize: 15, color: Color(0xFF334155), height: 1.5),
        ),
        const SizedBox(height: 20),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Text(
              deviceId,
              style: const TextStyle(fontSize: 22, letterSpacing: 2, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButtons() {
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _currentStep--),
              child: const Text('Back'),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (_currentStep == 1 && !_notificationGranted) {
                _requestNotificationPermission();
              } else if (_currentStep == 2 && !_batteryOptimized) {
                _requestBatteryOptimization();
              } else if (_currentStep == 3 && !_projectionTested) {
                _testMediaProjection();
              } else {
                _nextStep();
              }
            },
            child: Text(
              _currentStep == 4 ? 'Finish Setup' : 'Continue',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
