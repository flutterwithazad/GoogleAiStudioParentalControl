import 'package:flutter/material.dart';
import 'package:screen_mirror_shared/enums.dart';
import 'package:screen_mirror_shared/webrtc/webrtc_service.dart';
import '../services/parent_session_service.dart';
import 'parent_viewer_screen.dart';

class ParentHomeScreen extends StatefulWidget {
  final ParentSessionService sessionService;
  final WebRTCService webRTCService;
  final String childDeviceId;
  final String childDeviceName;

  const ParentHomeScreen({
    super.key,
    required this.sessionService,
    required this.webRTCService,
    this.childDeviceId = 'child_android_s24',
    this.childDeviceName = "Child's Galaxy A54",
  });

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  ParentPresenceState _presenceState = ParentPresenceState.ready;
  MirrorSessionState _sessionState = MirrorSessionState.idle;

  @override
  void initState() {
    super.initState();
    _bindStreams();
  }

  void _bindStreams() {
    widget.sessionService.onPresenceChanged.listen((presence) {
      if (mounted) setState(() => _presenceState = presence);
    });

    widget.sessionService.onSessionStateChanged.listen((state) {
      if (mounted) setState(() => _sessionState = state);
    });
  }

  Color _getPresenceColor() {
    switch (_presenceState) {
      case ParentPresenceState.ready:
      case ParentPresenceState.online:
        return const Color(0xFF10B981); // Emerald Green
      case ParentPresenceState.mirroring:
        return const Color(0xFF3B82F6); // Blue
      case ParentPresenceState.reconnecting:
        return const Color(0xFFF59E0B); // Amber
      case ParentPresenceState.authorizationRequired:
        return const Color(0xFFF97316); // Orange
      case ParentPresenceState.offline:
      case ParentPresenceState.unavailable:
      default:
        return const Color(0xFF9CA3AF); // Gray
    }
  }

  void _startMirroring() {
    widget.sessionService.requestSession(childDeviceId: widget.childDeviceId);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ParentViewerScreen(
          sessionService: widget.sessionService,
          webRTCService: widget.webRTCService,
          childDeviceName: widget.childDeviceName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canViewScreen = (_presenceState == ParentPresenceState.ready ||
        _presenceState == ParentPresenceState.online);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Parent Device',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Child Device',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 16),

            // Child Device Card
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
                      Text(
                        widget.childDeviceName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getPresenceColor().withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _getPresenceColor(),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _presenceState.toDisplayString().toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getPresenceColor(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Device ID: child_android_s24',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Android OS: 14 (API 34) • Background Persistence: Active',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                  const Divider(height: 32, color: Color(0xFFE5E7EB)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Mirroring Session',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      Text(
                        _sessionState.toDisplayString(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),

            // VIEW SCREEN Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFE5E7EB),
                  disabledForegroundColor: const Color(0xFF9CA3AF),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: canViewScreen ? _startMirroring : null,
                child: const Text(
                  'VIEW SCREEN',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
