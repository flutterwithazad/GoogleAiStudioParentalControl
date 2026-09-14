import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:screen_mirror_shared/enums.dart';
import 'package:screen_mirror_shared/webrtc/webrtc_service.dart';
import '../services/parent_session_service.dart';

class ParentViewerScreen extends StatefulWidget {
  final ParentSessionService sessionService;
  final WebRTCService webRTCService;
  final String childDeviceName;

  const ParentViewerScreen({
    super.key,
    required this.sessionService,
    required this.webRTCService,
    required this.childDeviceName,
  });

  @override
  State<ParentViewerScreen> createState() => _ParentViewerScreenState();
}

class _ParentViewerScreenState extends State<ParentViewerScreen> {
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  MirrorSessionState _sessionState = MirrorSessionState.connecting;
  WebRTCStats _stats = const WebRTCStats();

  @override
  void initState() {
    super.initState();
    _initRenderer();
    _bindStreams();
  }

  Future<void> _initRenderer() async {
    await _remoteRenderer.initialize();
    widget.webRTCService.attachRemoteRenderer(_remoteRenderer);
  }

  void _bindStreams() {
    widget.sessionService.onSessionStateChanged.listen((state) {
      if (mounted) {
        setState(() => _sessionState = state);
        if (state == MirrorSessionState.ended || state == MirrorSessionState.idle) {
          Navigator.of(context).pop();
        }
      }
    });

    widget.webRTCService.onStats.listen((stats) {
      if (mounted) {
        setState(() => _stats = stats);
      }
    });
  }

  @override
  void dispose() {
    _remoteRenderer.dispose();
    super.dispose();
  }

  Color _getConnectionBadgeColor() {
    switch (_sessionState) {
      case MirrorSessionState.connected:
        return const Color(0xFF10B981); // Emerald Green
      case MirrorSessionState.connecting:
        return const Color(0xFFF59E0B); // Amber
      case MirrorSessionState.reconnecting:
        return const Color(0xFFEF4444); // Red/Orange warning
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _getConnectionStatusLabel() {
    switch (_sessionState) {
      case MirrorSessionState.connected:
        return 'CONNECTED';
      case MirrorSessionState.connecting:
        return 'CONNECTING...';
      case MirrorSessionState.reconnecting:
        return 'RECONNECTING (ICE RESTAR)';
      case MirrorSessionState.failed:
        return 'FAILED';
      default:
        return 'DISCONNECTED';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top HUD Bar: Child Name, Connection State, Live Telemetry
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF111827),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getConnectionBadgeColor(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getConnectionStatusLabel(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${_stats.width}x${_stats.height} • ${_stats.fps.toStringAsFixed(0)} FPS • ${_stats.bitrateKbps} kbps',
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Live WebRTC Video Viewport
            Expanded(
              child: Center(
                child: _sessionState == MirrorSessionState.connected
                    ? RTCVideoView(
                        _remoteRenderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 44,
                            height: 44,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _sessionState == MirrorSessionState.reconnecting
                                ? 'Reconnecting WebRTC media stream...'
                                : 'Waiting for child device authorization...',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // Bottom Action Bar: STOP MIRRORING ONLY
            Container(
              padding: const EdgeInsets.all(16.0),
              color: const Color(0xFF111827),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    await widget.sessionService.stopSession();
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text(
                    'STOP MIRRORING',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
