import 'dart:developer' as dev;
import 'enums.dart';

/// Centralized structured logger with automatic redaction of sensitive credentials.
class AppLogger {
  static bool enableConsoleOutput = true;

  static void log(LogCategory category, String message, {Map<String, dynamic>? metadata, Object? error, StackTrace? stackTrace}) {
    final sanitizedMessage = _sanitize(message);
    final tag = category.tag;
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);

    final formatted = '$timestamp $tag $sanitizedMessage';

    if (enableConsoleOutput) {
      dev.log(
        formatted,
        name: tag.replaceAll('[', '').replaceAll(']', ''),
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static void screenCapture(String message, [Map<String, dynamic>? meta]) =>
      log(LogCategory.screenCapture, message, metadata: meta);

  static void mediaProjection(String message, [Map<String, dynamic>? meta]) =>
      log(LogCategory.mediaProjection, message, metadata: meta);

  static void foregroundService(String message, [Map<String, dynamic>? meta]) =>
      log(LogCategory.foregroundService, message, metadata: meta);

  static void webrtc(String message, [Map<String, dynamic>? meta]) =>
      log(LogCategory.webrtc, message, metadata: meta);

  static void signaling(String message, [Map<String, dynamic>? meta]) =>
      log(LogCategory.signaling, message, metadata: meta);

  static void session(String message, [Map<String, dynamic>? meta]) =>
      log(LogCategory.session, message, metadata: meta);

  /// Strips potential tokens, passwords, private keys, or full SDP credentials
  static String _sanitize(String input) {
    return input
        .replaceAll(RegExp(r'(Bearer\s+)[A-Za-z0-9-_.]+'), r'$1[REDACTED]')
        .replaceAll(RegExp(r'(token|password|secret|credential|auth_key)=([^\s&]+)', caseSensitive: false), r'$1=[REDACTED]')
        .replaceAll(RegExp(r'(a=ice-pwd:)[^\r\n]+'), r'$1[REDACTED_ICE_PWD]')
        .replaceAll(RegExp(r'(a=ice-ufrag:)[^\r\n]+'), r'$1[REDACTED_ICE_UFRAG]');
  }
}
