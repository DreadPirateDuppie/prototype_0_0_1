import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/service_locator.dart';
import 'dart:developer' as developer;

class ErrorService {
  static SupabaseClient get _client {
    if (getIt.isRegistered<SupabaseClient>()) {
      return getIt<SupabaseClient>();
    }
    return Supabase.instance.client;
  }

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
      final user = _client.auth.currentUser;
      
      // Log to console in debug mode
      if (kDebugMode) {
        developer.log('Error tracked: $error', name: 'ErrorService', error: error, stackTrace: StackTrace.fromString(stackTrace));
      }

      await _client.from('error_logs').insert({
        'user_id': user?.id,
        'error_message': error.substring(0, error.length > 1000 ? 1000 : error.length),
        'stack_trace': stackTrace.substring(0, stackTrace.length > 4000 ? 4000 : stackTrace.length),
        'error_type': errorType,
        'created_at': DateTime.now().toIso8601String(),
        'severity': 'error',
      });
      
    } catch (e) {
      // Fail silently to avoid infinite error loops
      developer.log('Failed to log error to Supabase: $e', name: 'ErrorService');
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
