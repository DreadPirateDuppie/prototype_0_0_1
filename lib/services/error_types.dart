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
    super.message, {
    String? userMessage,
    super.originalError,
  }) : super(
    userMessage: userMessage ?? 'Network error. Please check your connection and try again.',
  );
}

/// Validation errors
class AppValidationException extends AppException {
  final Map<String, String>? fieldErrors;
  
  AppValidationException(
    super.message, {
    String? userMessage,
    this.fieldErrors,
    super.originalError,
  }) : super(
    userMessage: userMessage ?? 'Please check your input and try again.',
  );
}

/// Authentication errors
class AppAuthException extends AppException {
  AppAuthException(
    super.message, {
    String? userMessage,
    super.originalError,
  }) : super(
    userMessage: userMessage ?? 'Authentication failed. Please sign in again.',
  );
}

/// Server errors
class AppServerException extends AppException {
  final int? statusCode;
  
  AppServerException(
    super.message, {
    String? userMessage,
    this.statusCode,
    super.originalError,
  }) : super(
    userMessage: userMessage ?? 'Server error. Please try again later.',
  );
}

/// Timeout errors
class AppTimeoutException extends AppException {
  AppTimeoutException(
    super.message, {
    String? userMessage,
    super.originalError,
  }) : super(
    userMessage: userMessage ?? 'Request timed out. Please try again.',
  );
}

/// Permission errors
class AppPermissionException extends AppException {
  AppPermissionException(
    super.message, {
    String? userMessage,
    super.originalError,
  }) : super(
    userMessage: userMessage ?? 'You don\'t have permission to perform this action.',
  );
}

/// Not found errors
class AppNotFoundException extends AppException {
  AppNotFoundException(
    super.message, {
    String? userMessage,
    super.originalError,
  }) : super(
    userMessage: userMessage ?? 'The requested item was not found.',
  );
}

/// Conflict errors (e.g., duplicate entries)
class AppConflictException extends AppException {
  AppConflictException(
    super.message, {
    String? userMessage,
    super.originalError,
  }) : super(
    userMessage: userMessage ?? 'This action conflicts with existing data.',
  );
}

/// Rate limit errors
class AppRateLimitException extends AppException {
  final Duration? retryAfter;
  
  AppRateLimitException(
    super.message, {
    String? userMessage,
    this.retryAfter,
    super.originalError,
  }) : super(
    userMessage: userMessage ?? 'Too many requests. Please wait a moment and try again.',
  );
}

/// Storage/cache errors
class AppStorageException extends AppException {
  AppStorageException(
    super.message, {
    String? userMessage,
    super.originalError,
  }) : super(
    userMessage: userMessage ?? 'Storage error. Please check available space.',
  );
}
