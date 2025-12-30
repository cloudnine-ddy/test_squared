class TopicStatsModel {
  final String userId;
  final String topicId;
  final int totalAttempts;
  final int correctCount;
  final double avgScore;
  final DateTime? lastPracticed;
  final int uniqueQuestionsAttempted;

  const TopicStatsModel({
    required this.userId,
    required this.topicId,
    required this.totalAttempts,
    required this.correctCount,
    required this.avgScore,
    this.lastPracticed,
    required this.uniqueQuestionsAttempted,
  });

  // Computed properties
  double get accuracyRate {
    if (totalAttempts == 0) return 0.0;
    return (correctCount / totalAttempts) * 100;
  }

  String get accuracyDisplay => '${accuracyRate.toStringAsFixed(1)}%';

  /// Returns mastery level based on accuracy and attempts
  /// - beginner: < 50% accuracy or < 5 attempts
  /// - intermediate: 50-80% accuracy with 5+ attempts
  /// - advanced: > 80% accuracy with 10+ attempts
  String get masteryLevel {
    if (totalAttempts < 5 || accuracyRate < 50) {
      return 'beginner';
    } else if (totalAttempts < 10 || accuracyRate < 80) {
      return 'intermediate';
    } else {
      return 'advanced';
    }
  }

  String get masteryDisplay {
    switch (masteryLevel) {
      case 'beginner':
        return 'Beginner';
      case 'intermediate':
        return 'Intermediate';
      case 'advanced':
        return 'Advanced';
      default:
        return 'Unknown';
    }
  }

  String get lastPracticedDisplay {
    if (lastPracticed == null) return 'Never';
    
    final now = DateTime.now();
    final difference = now.difference(lastPracticed!);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = difference.inDays ~/ 7;
      return '${weeks}w ago';
    } else {
      final months = difference.inDays ~/ 30;
      return '${months}mo ago';
    }
  }

  factory TopicStatsModel.fromMap(Map<String, dynamic> map) {
    return TopicStatsModel(
      userId: map['user_id']?.toString() ?? '',
      topicId: map['topic_id']?.toString() ?? '',
      totalAttempts: map['total_attempts'] as int? ?? 0,
      correctCount: map['correct_count'] as int? ?? 0,
      avgScore: (map['avg_score'] as num?)?.toDouble() ?? 0.0,
      lastPracticed: map['last_practiced'] != null
          ? (map['last_practiced'] is String
              ? DateTime.parse(map['last_practiced'])
              : map['last_practiced'] as DateTime)
          : null,
      uniqueQuestionsAttempted: map['unique_questions_attempted'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'topic_id': topicId,
      'total_attempts': totalAttempts,
      'correct_count': correctCount,
      'avg_score': avgScore,
      'last_practiced': lastPracticed?.toIso8601String(),
      'unique_questions_attempted': uniqueQuestionsAttempted,
    };
  }
}
