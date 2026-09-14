import 'package:flutter/material.dart';
import 'package:screen_mirror_shared/signaling/signaling_service.dart';
import 'package:screen_mirror_shared/webrtc/webrtc_service.dart';
import 'screens/parent_home_screen.dart';
import 'services/parent_session_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final signalingService = SupabaseSignalingService();
  final webRTCService = WebRTCService();
  final sessionService = ParentSessionService(
    signalingService: signalingService,
    webRTCService: webRTCService,
  )..initialize();

  runApp(ParentApp(
    sessionService: sessionService,
    webRTCService: webRTCService,
  ));
}

class ParentApp extends StatelessWidget {
  final ParentSessionService sessionService;
  final WebRTCService webRTCService;

  const ParentApp({
    super.key,
    required this.sessionService,
    required this.webRTCService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parental Screen Mirror - Parent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          primary: const Color(0xFF2563EB),
        ),
        useMaterial3: true,
      ),
      home: ParentHomeScreen(
        sessionService: sessionService,
        webRTCService: webRTCService,
      ),
    );
  }
}
