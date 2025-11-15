/// Base class for all app-specific exceptions
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const AppException(this.message, {this.code, this.details});

  @override
  String toString() => '[$runtimeType] $message${code != null ? ' (Code: $code)' : ''}';
}

/// Thrown when there's an authentication error
class AuthException extends AppException {
  const AuthException(String message, {String? code, dynamic details})
      : super(message, code: code, details: details);
}

/// Thrown when there's a network error
class NetworkException extends AppException {
  const NetworkException(String message, {String? code, dynamic details})
      : super(message, code: code, details: details);
}

/// Thrown when there's a data validation error
class ValidationException extends AppException {
  const ValidationException(String message, {String? code, dynamic details})
      : super(message, code: code, details: details);
}

/// Thrown when a requested resource is not found
class NotFoundException extends AppException {
  const NotFoundException(String message, {String? code, dynamic details})
      : super(message, code: code, details: details);
}

/// Thrown when there's a permission error
class PermissionException extends AppException {
  const PermissionException(String message, {String? code, dynamic details})
      : super(message, code: code, details: details);
}
