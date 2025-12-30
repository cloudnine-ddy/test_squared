import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for tracking topic-based progress
class TopicProgressRepository {
  final _supabase = Supabase.instance.client;

  /// Get progress for a specific topic and user
  Future<Map<String, dynamic>> getTopicProgress({
    required String userId,
    required String topicId,
  }) async {
    try {
      final result = await _supabase.rpc(
        'get_topic_progress',
        params: {
          'p_user_id': userId,
          'p_topic_id': topicId,
        },
      );

      if (result == null || (result as List).isEmpty) {
        return {
          'topic_id': topicId,
          'total_questions': 0,
          'completed_questions': 0,
          'progress_percentage': 0.0,
        };
      }

      return result[0] as Map<String, dynamic>;
    } catch (e) {
      print('Error getting topic progress: $e');
      return {
        'topic_id': topicId,
        'total_questions': 0,
        'completed_questions': 0,
        'progress_percentage': 0.0,
      };
    }
  }

  /// Get daily question solving statistics
  Future<List<Map<String, dynamic>>> getDailyQuestionStats({
    required String userId,
    int days = 30,
  }) async {
    try {
      final result = await _supabase.rpc(
        'get_daily_question_stats',
        params: {
          'p_user_id': userId,
          'p_days': days,
        },
      );

      if (result == null) return [];
      
      return (result as List).map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error getting daily stats: $e');
      return [];
    }
  }

  /// Get progress for multiple topics at once
  Future<Map<String, Map<String, dynamic>>> getBatchTopicProgress({
    required String userId,
    required List<String> topicIds,
  }) async {
    final results = <String, Map<String, dynamic>>{};
    
    for (final topicId in topicIds) {
      results[topicId] = await getTopicProgress(
        userId: userId,
        topicId: topicId,
      );
    }
    
    return results;
  }

  /// Mark a question as completed (correct answer)
  Future<void> markQuestionCompleted({
    required String userId,
    required String questionId,
    required bool isCorrect,
  }) async {
    try {
      await _supabase.from('user_question_attempts').insert({
        'user_id': userId,
        'question_id': questionId,
        'is_correct': isCorrect,
        'attempted_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error marking question completed: $e');
      rethrow;
    }
  }
}
