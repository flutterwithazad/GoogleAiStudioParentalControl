import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/enums.dart';
import '../../services/session_service.dart';
import '../../services/webrtc_service.dart';

class ParentScreen extends StatefulWidget {
  final SessionService sessionService;
  final WebRTCService webRTCService;
  final String childDeviceId;
  final String childDeviceName;
  final ParentPresenceState initialPresence;
  final String lastSeen;

  const ParentScreen({
    super.key,
    required this.sessionService,
    required this.webRTCService,
    this.childDeviceId = 'child_android_s24',
    this.childDeviceName = "Child's Galaxy A54",
    this.initialPresence = ParentPresenceState.ready,
    this.lastSeen = 'Just now',
  });

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  MirrorSessionState _sessionState = MirrorSessionState.idle;
  late ParentPresenceState _presenceState;
  WebRTCStats _stats = const WebRTCStats();

  @override
  void initState() {
    super.initState();
    _presenceState = widget.initialPresence;
    _initRenderer();
    _listenSessionState();
  }

  Future<void> _initRenderer() async {
    await _remoteRenderer.initialize();
    widget.webRTCService.attachRemoteRenderer(_remoteRenderer);
  }

  void _listenSessionState() {
    widget.sessionService.onSessionStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _sessionState = state;
          if (state == MirrorSessionState.connected) {
            _presenceState = ParentPresenceState.mirroring;
          } else if (state == MirrorSessionState.reconnecting) {
            _presenceState = ParentPresenceState.reconnecting;
          } else if (state == MirrorSessionState.ended || state == MirrorSessionState.idle) {
            _presenceState = ParentPresenceState.ready;
          } else if (state == MirrorSessionState.failed) {
            _presenceState = ParentPresenceState.authorizationRequired;
          }
        });
      }
    });

    widget.webRTCService.onStats.listen((stats) {
      if (mounted) setState(() => _stats = stats);
    });
  }

  @override
  void dispose() {
    _remoteRenderer.dispose();
    super.dispose();
  }

  void _handleViewScreen() {
    widget.sessionService.requestSession(childDeviceId: widget.childDeviceId);
  }

  void _handleStopScreen() {
    widget.sessionService.stopSession();
  }

  Color _getPresenceColor(ParentPresenceState state) {
    switch (state) {
      case ParentPresenceState.online:
      case ParentPresenceState.ready:
        return Colors.green;
      case ParentPresenceState.mirroring:
        return Colors.blue;
      case ParentPresenceState.reconnecting:
        return Colors.amber;
      case ParentPresenceState.authorizationRequired:
        return Colors.orange;
      case ParentPresenceState.offline:
      case ParentPresenceState.unavailable:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // When viewing active mirror session: Parent screen shows ONLY Live video,
    // Connection status, Current resolution, Current FPS, Approximate bitrate, Stop button.
    if (_sessionState == MirrorSessionState.connecting ||
        _sessionState == MirrorSessionState.connected ||
        _sessionState == MirrorSessionState.reconnecting) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              // HUD overlay with connection status, resolution, FPS, bitrate
              Container(
                color: Colors.black.withOpacity(0.85),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            color: _sessionState == MirrorSessionState.connected
                                ? Colors.greenAccent
                                : Colors.amberAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _sessionState.toDisplayString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${_stats.width}x${_stats.height} • ${_stats.fps.toStringAsFixed(0)} FPS • ${_stats.bitrateKbps} kbps',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),

              // Live video viewport
              Expanded(
                child: Center(
                  child: _sessionState == MirrorSessionState.connected
                      ? RTCVideoView(
                          _remoteRenderer,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 16),
                            Text(
                              'Waiting for Child authorization...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                ),
              ),

              // Stop button only
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _handleStopScreen,
                    child: const Text(
                      'Stop Mirroring',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Default Main Screen
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Parent Control', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
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
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
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
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getPresenceColor(_presenceState),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _presenceState.toDisplayString(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _getPresenceColor(_presenceState),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last Seen: ${widget.lastSeen}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Mirroring Session',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                      Text(
                        _sessionState.toDisplayString(),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: (_presenceState == ParentPresenceState.ready ||
                        _presenceState == ParentPresenceState.online)
                    ? _handleViewScreen
                    : null,
                child: const Text(
                  'View Screen',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
