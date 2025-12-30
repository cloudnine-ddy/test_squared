import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  /// Log a custom event
  void logEvent(String eventName, {Map<String, dynamic>? parameters}) {
    if (kDebugMode) {
      print('Analytics Event: $eventName');
      if (parameters != null) {
        print('Parameters: $parameters');
      }
    }

    // TODO: Integrate with Firebase Analytics or similar
    // FirebaseAnalytics.instance.logEvent(
    //   name: eventName,
    //   parameters: parameters,
    // );
  }

  /// Log screen view
  void logScreenView(String screenName) {
    logEvent('screen_view', parameters: {
      'screen_name': screenName,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Log user action
  void logUserAction(String action, {Map<String, dynamic>? details}) {
    logEvent('user_action', parameters: {
      'action': action,
      ...?details,
    });
  }

  /// Log error
  void logError(dynamic error, String? context) {
    if (kDebugMode) {
      print('Analytics Error: $error in $context');
    }

    // TODO: Integrate with error tracking service (Sentry, Crashlytics)
    // Sentry.captureException(error, stackTrace: stackTrace);
  }

  /// Log performance metric
  void logPerformance(String metric, Duration duration) {
    if (kDebugMode) {
      print('Performance: $metric took ${duration.inMilliseconds}ms');
    }

    logEvent('performance', parameters: {
      'metric': metric,
      'duration_ms': duration.inMilliseconds,
    });
  }

  /// Track question attempt
  void trackQuestionAttempt({
    required String questionId,
    required bool isCorrect,
    required int score,
    required Duration timeSpent,
  }) {
    logEvent('question_attempt', parameters: {
      'question_id': questionId,
      'is_correct': isCorrect,
      'score': score,
      'time_spent_seconds': timeSpent.inSeconds,
    });
  }

  /// Track search
  void trackSearch(String query, int resultCount) {
    logEvent('search', parameters: {
      'query': query,
      'result_count': resultCount,
    });
  }

  /// Track bookmark action
  void trackBookmark(String questionId, bool isAdding) {
    logEvent('bookmark', parameters: {
      'question_id': questionId,
      'action': isAdding ? 'add' : 'remove',
    });
  }

  /// Track note action
  void trackNote(String questionId, String action) {
    logEvent('note', parameters: {
      'question_id': questionId,
      'action': action, // 'create', 'update', 'delete'
    });
  }
}
