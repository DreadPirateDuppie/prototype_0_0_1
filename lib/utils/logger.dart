import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// A production-safe logging utility.
/// Only prints logs when the app is in debug mode (kDebugMode).
class AppLogger {
  /// Log a message for debugging.
  static void log(String message, {String name = 'App', Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      developer.log(
        message,
        name: name,
        error: error,
        stackTrace: stackTrace,
        time: DateTime.now(),
      );
    }
  }

  /// Log a warning message (visible in all modes but potentially useful to track in prod if sent to an error service).
  /// For now, we still guard it with kDebugMode unless we integrate an error tracking service.
  static void warn(String message, {String name = 'App'}) {
    if (kDebugMode) {
      debugPrint('[$name] WARNING: $message');
    }
  }

  /// Log an error message.
  static void error(String message, {String name = 'App', Object? error, StackTrace? stackTrace}) {
    // In production, you might want to send this to Sentry/Crashlytics
    if (kDebugMode) {
      developer.log(
        'ERROR: $message',
        name: name,
        error: error,
        stackTrace: stackTrace,
        time: DateTime.now(),
      );
    }
  }
}
