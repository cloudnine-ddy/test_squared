import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/question_attempt_model.dart';
import '../models/topic_stats_model.dart';
import '../../past_papers/models/question_model.dart';

class ProgressRepository {
  final _supabase = Supabase.instance.client;

  /// Record a new question attempt
  Future<void> recordAttempt(QuestionAttemptModel attempt) async {
    await _supabase.from('user_question_attempts').insert(attempt.toMap());
    
    // Refresh materialized view in background (don't await)
    _refreshStatsAsync();
  }

  /// Get all attempts for a user
  Future<List<QuestionAttemptModel>> getUserAttempts(
    String userId, {
    int? limit,
    int? offset,
  }) async {
    var query = _supabase
        .from('user_question_attempts')
        .select()
        .eq('user_id', userId)
        .order('attempted_at', ascending: false);

    if (limit != null) {
      query = query.limit(limit);
    }
    if (offset != null) {
      query = query.range(offset, offset + (limit ?? 10) - 1);
    }

    final data = await query;
    return (data as List)
        .map((json) => QuestionAttemptModel.fromMap(json))
        .toList();
  }

  /// Get attempts for a specific question by a user
  Future<List<QuestionAttemptModel>> getQuestionAttempts(
    String userId,
    String questionId,
  ) async {
    final data = await _supabase
        .from('user_question_attempts')
        .select()
        .eq('user_id', userId)
        .eq('question_id', questionId)
        .order('attempted_at', ascending: false);

    return (data as List)
        .map((json) => QuestionAttemptModel.fromMap(json))
        .toList();
  }

  /// Get topic statistics for a user
  Future<List<TopicStatsModel>> getUserTopicStats(String userId) async {
    final data = await _supabase
        .from('user_topic_stats')
        .select()
        .eq('user_id', userId)
        .order('total_attempts', ascending: false);

    return (data as List)
        .map((json) => TopicStatsModel.fromMap(json))
        .toList();
  }

  /// Get statistics for a specific topic
  Future<TopicStatsModel?> getTopicStats(
    String userId,
    String topicId,
  ) async {
    final data = await _supabase
        .from('user_topic_stats')
        .select()
        .eq('user_id', userId)
        .eq('topic_id', topicId)
        .maybeSingle();

    if (data == null) return null;
    return TopicStatsModel.fromMap(data);
  }

  /// Get overall statistics for a user
  Future<Map<String, dynamic>> getUserOverallStats(String userId) async {
    final result = await _supabase.rpc('get_user_overall_stats', params: {
      'p_user_id': userId,
    });

    if (result == null || result.isEmpty) {
      return {
        'total_attempts': 0,
        'total_questions_attempted': 0,
        'total_correct': 0,
        'overall_accuracy': 0.0,
        'avg_score': 0.0,
        'total_time_spent': 0,
        'current_streak': 0,
        'longest_streak': 0,
      };
    }

    return result is List ? result.first : result;
  }

  /// Get weak areas for a user (topics with low accuracy)
  Future<List<Map<String, dynamic>>> getWeakAreas(
    String userId, {
    int limit = 5,
  }) async {
    final result = await _supabase.rpc('get_user_weak_areas', params: {
      'p_user_id': userId,
      'p_limit': limit,
    });

    return (result as List).cast<Map<String, dynamic>>();
  }

  /// Get questions from weak areas for practice
  Future<List<QuestionModel>> getWeakAreaQuestions(
    String userId, {
    int limit = 10,
  }) async {
    // Get weak topic IDs
    final weakAreas = await getWeakAreas(userId, limit: 3);
    if (weakAreas.isEmpty) {
      return [];
    }

    final weakTopicIds = weakAreas
        .map((area) => area['topic_id'] as String)
        .toList();

    // Get questions from these topics that user hasn't attempted or got wrong
    final attemptedQuestionIds = await _getAttemptedQuestionIds(userId);

    final data = await _supabase
        .from('questions')
        .select('*, papers(*)')
        .overlaps('topic_ids', weakTopicIds)
        .not('id', 'in', attemptedQuestionIds.isEmpty ? [''] : attemptedQuestionIds)
        .limit(limit);

    return (data as List)
        .map((json) => QuestionModel.fromMap(json))
        .toList();
  }

  /// Get recently attempted questions
  Future<List<Map<String, dynamic>>> getRecentActivity(
    String userId, {
    int limit = 10,
  }) async {
    final data = await _supabase
        .from('user_question_attempts')
        .select('*, questions(id, question_number, content, image_url)')
        .eq('user_id', userId)
        .order('attempted_at', ascending: false)
        .limit(limit);

    return (data as List).cast<Map<String, dynamic>>();
  }

  /// Check if user has attempted a question
  Future<bool> hasAttempted(String userId, String questionId) async {
    final data = await _supabase
        .from('user_question_attempts')
        .select('id')
        .eq('user_id', userId)
        .eq('question_id', questionId)
        .limit(1);

    return (data as List).isNotEmpty;
  }

  /// Get the last attempt for a question
  Future<QuestionAttemptModel?> getLastAttempt(
    String userId,
    String questionId,
  ) async {
    final data = await _supabase
        .from('user_question_attempts')
        .select()
        .eq('user_id', userId)
        .eq('question_id', questionId)
        .order('attempted_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (data == null) return null;
    return QuestionAttemptModel.fromMap(data);
  }

  /// Helper: Get list of attempted question IDs
  Future<List<String>> _getAttemptedQuestionIds(String userId) async {
    final data = await _supabase
        .from('user_question_attempts')
        .select('question_id')
        .eq('user_id', userId);

    return (data as List)
        .map((row) => row['question_id'] as String)
        .toSet()
        .toList();
  }

  /// Refresh materialized view asynchronously
  void _refreshStatsAsync() {
    _supabase.rpc('refresh_user_topic_stats').catchError((error) {
      print('Failed to refresh stats: $error');
    });
  }
}
