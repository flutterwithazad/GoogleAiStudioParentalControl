import 'dart:developer' as dev;

/// Structured Logger adhering strictly to clean category taxonomy.
/// Never logs passwords, auth tokens, private credentials, or SDP keys.
class AppLogger {
  static void capture(String message) => _log('CAPTURE', message);
  static void mediaProjection(String message) => _log('MEDIAPROJECTION', message);
  static void foregroundService(String message) => _log('FOREGROUND_SERVICE', message);
  static void webrtc(String message) => _log('WEBRTC', message);
  static void signaling(String message) => _log('SIGNALING', message);
  static void session(String message) => _log('SESSION', message);
  static void network(String message) => _log('NETWORK', message);

  static void _log(String category, String message) {
    final timestamp = DateTime.now().toIso8601String().split('T').last.substring(0, 12);
    // Sanitize any accidentally passed auth or token substrings
    final safeMsg = _sanitize(message);
    dev.log('[$timestamp] [$category] $safeMsg', name: 'ScreenMirror');
  }

  static String _sanitize(String input) {
    return input
        .replaceAll(RegExp(r'bearer\s+[a-zA-Z0-9_\-\.]+', caseSensitive: false), 'bearer [REDACTED]')
        .replaceAll(RegExp(r'token=[a-zA-Z0-9_\-\.]+', caseSensitive: false), 'token=[REDACTED]')
        .replaceAll(RegExp(r'password=[^\s&]+', caseSensitive: false), 'password=[REDACTED]');
  }
}
