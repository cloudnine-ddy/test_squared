import 'package:flutter/material.dart';

/// Helper class to determine question status based on attempt data
class QuestionStatusHelper {
  /// Get status color for a question based on attempt
  static Color getStatusColor(Map<String, dynamic>? latestAttempt) {
    if (latestAttempt == null) {
      return Colors.grey.shade300; // No attempt yet (Beige/Default)
    }

    final score = latestAttempt['score'] as int?;
    final isCorrect = latestAttempt['is_correct'] as bool?;

    if (isCorrect == true || (score != null && score > 80)) {
      return Colors.green.shade400; // Correct (Green)
    } else if (score != null && score > 0) {
      return Colors.orange.shade400; // Partial (Yellow/Orange)
    } else {
      return Colors.red.shade400; // Incorrect (Red)
    }
  }

  /// Get status icon for a question based on attempt
  static IconData getStatusIcon(Map<String, dynamic>? latestAttempt) {
    if (latestAttempt == null) {
      return Icons.circle_outlined; // No attempt
    }

    final score = latestAttempt['score'] as int?;
    final isCorrect = latestAttempt['is_correct'] as bool?;

    if (isCorrect == true || (score != null && score > 80)) {
      return Icons.check_circle; // Correct
    } else if (score != null && score > 0) {
      return Icons.warning_amber_rounded; // Partial
    } else {
      return Icons.cancel; // Incorrect
    }
  }

  /// Get status text
  static String getStatusText(Map<String, dynamic>? latestAttempt) {
    if (latestAttempt == null) {
      return 'Not attempted';
    }

    final score = latestAttempt['score'] as int?;
    final isCorrect = latestAttempt['is_correct'] as bool?;

    if (isCorrect == true || (score != null && score > 80)) {
      return 'Completed';
    } else if (score != null && score > 0) {
      return 'Needs review';
    } else {
      return 'Incorrect';
    }
  }
}
