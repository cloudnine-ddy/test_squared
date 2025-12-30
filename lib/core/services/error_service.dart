import 'package:flutter/foundation.dart';

class ErrorService {
  static final ErrorService _instance = ErrorService._internal();
  factory ErrorService() => _instance;
  ErrorService._internal();

  /// Handle errors and return user-friendly messages
  String handleError(dynamic error, {String? context}) {
    if (kDebugMode) {
      print('Error in $context: $error');
    }

    // Log to analytics/monitoring service here
    // AnalyticsService().logError(error, context);

    return _getUserFriendlyMessage(error);
  }

  /// Get user-friendly error message
  String _getUserFriendlyMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Network errors
    if (errorString.contains('socket') || 
        errorString.contains('network') ||
        errorString.contains('connection')) {
      return 'Network error. Please check your internet connection.';
    }

    // Authentication errors
    if (errorString.contains('auth') || 
        errorString.contains('unauthorized') ||
        errorString.contains('forbidden')) {
      return 'Authentication error. Please log in again.';
    }

    // Database errors
    if (errorString.contains('duplicate') || 
        errorString.contains('unique constraint')) {
      return 'This item already exists.';
    }

    if (errorString.contains('foreign key') || 
        errorString.contains('violates')) {
      return 'Cannot perform this action due to data dependencies.';
    }

    // Timeout errors
    if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    // Permission errors
    if (errorString.contains('permission') || 
        errorString.contains('access denied')) {
      return 'You don\'t have permission to perform this action.';
    }

    // Not found errors
    if (errorString.contains('not found') || 
        errorString.contains('404')) {
      return 'The requested item was not found.';
    }

    // Generic error
    return 'Something went wrong. Please try again.';
  }

  /// Execute function with error handling and retry logic
  Future<T?> executeWithRetry<T>({
    required Future<T> Function() function,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
    String? context,
  }) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        return await function();
      } catch (error) {
        attempts++;
        
        if (attempts >= maxRetries) {
          handleError(error, context: context);
          rethrow;
        }

        // Wait before retrying
        await Future.delayed(retryDelay * attempts);
      }
    }
    
    return null;
  }

  /// Execute function with error handling (no retry)
  Future<T?> executeSafely<T>({
    required Future<T> Function() function,
    T? fallback,
    String? context,
  }) async {
    try {
      return await function();
    } catch (error) {
      handleError(error, context: context);
      return fallback;
    }
  }
}
