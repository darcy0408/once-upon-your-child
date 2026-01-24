/// Represents a structured error response from the backend API.
///
/// The backend returns errors in the format:
/// ```json
/// {
///   "error_code": "ERR_MODE_INVALID",
///   "message": "That combination doesn't work together yet.",
///   "hint": "Try turning off Rhymes or Pick-a-Path."
/// }
/// ```
class ApiError implements Exception {
  final String errorCode;
  final String message;
  final String? hint;

  ApiError({
    required this.errorCode,
    required this.message,
    this.hint,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) => ApiError(
        errorCode: (json['error_code'] ?? json['error'] ?? 'ERR_UNKNOWN').toString(),
        message: (json['message'] ?? json['error'] ?? 'Something went wrong.').toString(),
        hint: json['hint']?.toString(),
      );

  /// Returns true if this is a mode combination error (e.g., Pick-a-Path + Rhymes).
  bool get isModeCombinationError => errorCode == 'ERR_MODE_INVALID';

  /// Returns true if this is a rate limit error.
  bool get isRateLimitError => errorCode == 'RATE_LIMIT_EXCEEDED' || errorCode == 'QUOTA_EXCEEDED';

  /// Returns true if this is a network/connection error.
  bool get isNetworkError => errorCode == 'ERR_NETWORK' || errorCode == 'ERR_OFFLINE';

  /// Returns true if authentication is required.
  bool get isAuthError => errorCode == 'ERR_UNAUTHORIZED' || errorCode == 'ERR_AUTH_REQUIRED';

  /// User-friendly display message (includes hint if available).
  String get displayMessage {
    if (hint != null && hint!.isNotEmpty) {
      return '$message\n\n$hint';
    }
    return message;
  }

  @override
  String toString() => 'ApiError($errorCode): $message${hint != null ? " (Hint: $hint)" : ""}';
}
