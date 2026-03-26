/// Centralized error handling for user-friendly error messages
class ErrorHandler {
  /// Clean up error message by removing "Exception: " prefix
  static String cleanErrorMessage(dynamic error) {
    String message = error.toString();
    // Remove common prefixes
    if (message.startsWith('Exception: ')) {
      message = message.substring('Exception: '.length);
    }
    if (message.startsWith('Error: ')) {
      message = message.substring('Error: '.length);
    }
    return message;
  }

  /// Convert any error to a user-friendly message
  static String getUserFriendlyMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Network errors
    if (errorString.contains('socketexception') ||
        errorString.contains('connection refused') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('no internet')) {
      return 'Please check your internet connection and try again.';
    }

    // Timeout errors
    if (errorString.contains('timeout') || errorString.contains('timed out')) {
      return 'The request took too long. Please try again.';
    }

    // Server errors (5xx)
    if (errorString.contains('500') || errorString.contains('502') ||
        errorString.contains('503') || errorString.contains('504')) {
      return 'Our servers are having trouble. Please try again in a moment.';
    }

    // Not found (404)
    if (errorString.contains('404') || errorString.contains('not found')) {
      return 'The requested item could not be found.';
    }

    // Authentication errors
    if (errorString.contains('401') || errorString.contains('unauthorized')) {
      return 'Your session has expired. Please sign in again.';
    }

    // Forbidden (403)
    if (errorString.contains('403') || errorString.contains('forbidden')) {
      return 'You don\'t have permission to perform this action.';
    }

    // Rate limiting (429)
    if (errorString.contains('429') || errorString.contains('too many requests')) {
      return 'Too many requests. Please wait a moment and try again.';
    }

    // Bad request (400)
    if (errorString.contains('400') || errorString.contains('bad request')) {
      return 'Something went wrong with your request. Please try again.';
    }

    // Receipt-specific errors
    if (errorString.contains('not a receipt') ||
        errorString.contains("doesn't appear to be a receipt")) {
      return 'The uploaded image doesn\'t appear to be a receipt. Please upload a clear photo of your receipt.';
    }

    if (errorString.contains('processing failed')) {
      return 'We couldn\'t process your receipt. Please try uploading a clearer image.';
    }

    if (errorString.contains('extraction failed')) {
      return 'We couldn\'t read the receipt. Please make sure the image is clear and well-lit.';
    }

    // File/upload errors
    if (errorString.contains('file too large') || errorString.contains('payload too large')) {
      return 'The image is too large. Please try a smaller image.';
    }

    if (errorString.contains('upload failed')) {
      return 'Failed to upload the image. Please check your connection and try again.';
    }

    // Generic fallback
    return 'Something went wrong. Please try again.';
  }

  /// Parse error details from API response body if available
  static String? extractErrorDetail(String responseBody) {
    try {
      // Try to extract "detail" field from JSON error response
      if (responseBody.contains('"detail"')) {
        final detailMatch = RegExp(r'"detail"\s*:\s*"([^"]+)"').firstMatch(responseBody);
        if (detailMatch != null) {
          return detailMatch.group(1);
        }
      }
      // Try to extract "error" field
      if (responseBody.contains('"error"')) {
        final errorMatch = RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(responseBody);
        if (errorMatch != null) {
          return errorMatch.group(1);
        }
      }
    } catch (_) {
      // Ignore parsing errors
    }
    return null;
  }
}
