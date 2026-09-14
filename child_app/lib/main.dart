import 'package:flutter/material.dart';
import 'screens/child_dashboard_screen.dart';
import 'screens/child_setup_screen.dart';
import 'services/child_platform_bridge.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final platformBridge = ChildPlatformBridge();

  runApp(ChildApp(platformBridge: platformBridge));
}

class ChildApp extends StatefulWidget {
  final ChildPlatformBridge platformBridge;

  const ChildApp({super.key, required this.platformBridge});

  @override
  State<ChildApp> createState() => _ChildAppState();
}

class _ChildAppState extends State<ChildApp> {
  bool _isPaired = true; // Set to false to show setup wizard on first run

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parental Screen Mirror - Child',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          primary: const Color(0xFF2563EB),
        ),
        useMaterial3: true,
      ),
      home: _isPaired
          ? ChildDashboardScreen(platformBridge: widget.platformBridge)
          : ChildSetupScreen(
              platformBridge: widget.platformBridge,
              onPairingComplete: () => setState(() => _isPaired = true),
            ),
    );
  }
}
