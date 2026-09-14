import 'package:flutter/material.dart';
import 'core/logger.dart';
import 'services/signaling_service.dart';
import 'services/webrtc_service.dart';
import 'services/screen_capture_service.dart';
import 'services/device_service.dart';
import 'services/session_service.dart';
import 'features/parent/parent_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.session('Launching Flutter Parent App');

  final signaling = SupabaseSignalingService();
  final webrtc = WebRTCService();
  final capture = ScreenCaptureService();
  final device = DeviceService();

  await device.initialize();
  await signaling.connect(
    deviceId: 'parent_admin_id',
    authToken: 'authenticated_parent_jwt',
  );

  final session = SessionService(
    signalingService: signaling,
    webRTCService: webrtc,
    screenCaptureService: capture,
    deviceService: device,
  )..initialize();

  runApp(MaterialApp(
    title: 'ScreenMirror Parent',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
      useMaterial3: true,
    ),
    home: ParentScreen(
      sessionService: session,
      webRTCService: webrtc,
      childDeviceId: 'child_galaxy_a54',
      childDeviceName: "Child's Galaxy A54",
      isOnline: true,
      lastSeen: 'Just now',
    ),
  ));
}
