import 'package:flutter/foundation.dart';


class ErrorService {

  /// Initialize error tracking
  static void initialize() {
    // Capture Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _logError(
        details.exception.toString(),
        details.stack?.toString() ?? '',
        'FlutterError',
      );
    };

    // Capture errors not caught by Flutter framework
    PlatformDispatcher.instance.onError = (error, stack) {
      _logError(
        error.toString(),
        stack.toString(),
        'UncaughtError',
      );
      return true;
    };
  }

  /// Log error to Supabase
  static Future<void> _logError(
    String error,
    String stackTrace,
    String errorType,
  ) async {
    try {
      // TODO: Create error_logs table in database to enable error logging
      // final user = _client.auth.currentUser;
      // await _client.from('error_logs').insert({
      //   'user_id': user?.id,
      //   'error_message': error.substring(0, error.length > 500 ? 500 : error.length),
      //   'stack_trace': stackTrace.substring(0, stackTrace.length > 2000 ? 2000 : stackTrace.length),
      //   'error_type': errorType,
      //   'created_at': DateTime.now().toIso8601String(),
      // });
      
      // For now, just log to console in debug mode
      if (kDebugMode) {
      }
    } catch (e) {
      // Fail silently to avoid infinite error loops
      if (kDebugMode) {
      }
    }
  }

  /// Manually log an error
  static Future<void> logError(String message, [StackTrace? stackTrace]) async {
    _logError(
      message,
      stackTrace?.toString() ?? '',
      'ManualLog',
    );
  }
}
