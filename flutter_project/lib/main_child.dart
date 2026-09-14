import 'package:flutter/material.dart';
import 'core/enums.dart';
import 'core/logger.dart';
import 'services/signaling_service.dart';
import 'services/webrtc_service.dart';
import 'services/screen_capture_service.dart';
import 'services/device_service.dart';
import 'services/session_service.dart';
import 'features/child/child_dashboard_screen.dart';
import 'features/child/child_setup_wizard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.session('Launching Flutter Child App');

  final signaling = SupabaseSignalingService();
  final webrtc = WebRTCService();
  final capture = ScreenCaptureService();
  final device = DeviceService();

  await device.initialize();

  final session = SessionService(
    signalingService: signaling,
    webRTCService: webrtc,
    screenCaptureService: capture,
    deviceService: device,
  )..initialize();

  await signaling.connect(
    deviceId: device.deviceInfo?.deviceId ?? 'child_default',
    authToken: 'child_device_token',
  );

  runApp(ChildRootApp(
    deviceService: device,
    sessionService: session,
    screenCaptureService: capture,
  ));
}

class ChildRootApp extends StatefulWidget {
  final DeviceService deviceService;
  final SessionService sessionService;
  final ScreenCaptureService screenCaptureService;

  const ChildRootApp({
    super.key,
    required this.deviceService,
    required this.sessionService,
    required this.screenCaptureService,
  });

  @override
  State<ChildRootApp> createState() => _ChildRootAppState();
}

class _ChildRootAppState extends State<ChildRootApp> {
  bool _showingSetup = false;

  @override
  void initState() {
    super.initState();
    if (widget.deviceService.currentStatus == DeviceStatus.deviceNotConfigured) {
      _showingSetup = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScreenMirror Child',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: _showingSetup
          ? ChildSetupWizard(
              deviceService: widget.deviceService,
              screenCaptureService: widget.screenCaptureService,
              onComplete: () {
                setState(() => _showingSetup = false);
              },
            )
          : ChildDashboardScreen(
              deviceService: widget.deviceService,
              sessionService: widget.sessionService,
              screenCaptureService: widget.screenCaptureService,
              onOpenSetup: () {
                setState(() => _showingSetup = true);
              },
            ),
    );
  }
}
