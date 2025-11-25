/// Custom exception types for better error categorization and user-friendly messages

/// Base exception class for app-specific errors
abstract class AppException implements Exception {
  final String message;
  final String? userMessage;
  final dynamic originalError;
  
  AppException(this.message, {this.userMessage, this.originalError});
  
  @override
  String toString() => message;
  
  /// Get a user-friendly error message
  String getUserMessage() => userMessage ?? message;
}

/// Network-related errors
class AppNetworkException extends AppException {
  AppNetworkException(
    String message, {
    String? userMessage,
    dynamic originalError,
  }) : super(
    message,
    userMessage: userMessage ?? 'Network error. Please check your connection and try again.',
    originalError: originalError,
  );
}

/// Validation errors
class AppValidationException extends AppException {
  final Map<String, String>? fieldErrors;
  
  AppValidationException(
    String message, {
    String? userMessage,
    this.fieldErrors,
    dynamic originalError,
  }) : super(
    message,
    userMessage: userMessage ?? 'Please check your input and try again.',
    originalError: originalError,
  );
}

/// Authentication errors
class AppAuthException extends AppException {
  AppAuthException(
    String message, {
    String? userMessage,
    dynamic originalError,
  }) : super(
    message,
    userMessage: userMessage ?? 'Authentication failed. Please sign in again.',
    originalError: originalError,
  );
}

/// Server errors
class AppServerException extends AppException {
  final int? statusCode;
  
  AppServerException(
    String message, {
    String? userMessage,
    this.statusCode,
    dynamic originalError,
  }) : super(
    message,
    userMessage: userMessage ?? 'Server error. Please try again later.',
    originalError: originalError,
  );
}

/// Timeout errors
class AppTimeoutException extends AppException {
  AppTimeoutException(
    String message, {
    String? userMessage,
    dynamic originalError,
  }) : super(
    message,
    userMessage: userMessage ?? 'Request timed out. Please try again.',
    originalError: originalError,
  );
}

/// Permission errors
class AppPermissionException extends AppException {
  AppPermissionException(
    String message, {
    String? userMessage,
    dynamic originalError,
  }) : super(
    message,
    userMessage: userMessage ?? 'You don\'t have permission to perform this action.',
    originalError: originalError,
  );
}

/// Not found errors
class AppNotFoundException extends AppException {
  AppNotFoundException(
    String message, {
    String? userMessage,
    dynamic originalError,
  }) : super(
    message,
    userMessage: userMessage ?? 'The requested item was not found.',
    originalError: originalError,
  );
}

/// Conflict errors (e.g., duplicate entries)
class AppConflictException extends AppException {
  AppConflictException(
    String message, {
    String? userMessage,
    dynamic originalError,
  }) : super(
    message,
    userMessage: userMessage ?? 'This action conflicts with existing data.',
    originalError: originalError,
  );
}

/// Rate limit errors
class AppRateLimitException extends AppException {
  final Duration? retryAfter;
  
  AppRateLimitException(
    String message, {
    String? userMessage,
    this.retryAfter,
    dynamic originalError,
  }) : super(
    message,
    userMessage: userMessage ?? 'Too many requests. Please wait a moment and try again.',
    originalError: originalError,
  );
}

/// Storage/cache errors
class AppStorageException extends AppException {
  AppStorageException(
    String message, {
    String? userMessage,
    dynamic originalError,
  }) : super(
    message,
    userMessage: userMessage ?? 'Storage error. Please check available space.',
    originalError: originalError,
  );
}
