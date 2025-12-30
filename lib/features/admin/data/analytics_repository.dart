import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsRepository {
  final _supabase = Supabase.instance.client;

  /// Get overall platform analytics
  Future<Map<String, dynamic>> getOverallAnalytics() async {
    final result = await _supabase.rpc('get_platform_analytics');
    
    if (result == null || (result is List && result.isEmpty)) {
      return _getDefaultAnalytics();
    }

    return result is List ? result.first : result;
  }

  /// Get topic popularity statistics
  Future<List<Map<String, dynamic>>> getTopicPopularity({int limit = 10}) async {
    final result = await _supabase.rpc('get_topic_popularity', params: {
      'p_limit': limit,
    });

    return (result as List).cast<Map<String, dynamic>>();
  }

  /// Get user activity over time
  Future<List<Map<String, dynamic>>> getUserActivity({
    required DateTime from,
    required DateTime to,
  }) async {
    final data = await _supabase
        .from('user_question_attempts')
        .select('attempted_at, user_id, score, is_correct')
        .gte('attempted_at', from.toIso8601String())
        .lte('attempted_at', to.toIso8601String())
        .order('attempted_at');

    return (data as List).cast<Map<String, dynamic>>();
  }

  /// Get content metrics (papers, questions, subjects)
  Future<Map<String, dynamic>> getContentMetrics() async {
    final subjects = await _supabase
        .from('subjects')
        .select('id');
    
    final papers = await _supabase
        .from('papers')
        .select('id');
    
    final questions = await _supabase
        .from('questions')
        .select('id');
    
    final questionsWithFigures = await _supabase
        .from('questions')
        .select('id')
        .not('image_url', 'is', null);

    return {
      'total_subjects': (subjects as List).length,
      'total_papers': (papers as List).length,
      'total_questions': (questions as List).length,
      'questions_with_figures': (questionsWithFigures as List).length,
    };
  }

  /// Get recent admin activity
  Future<List<Map<String, dynamic>>> getRecentActivity({int limit = 20}) async {
    final data = await _supabase
        .from('admin_activity_log')
        .select('*, profiles(full_name)')
        .order('created_at', ascending: false)
        .limit(limit);

    return (data as List).cast<Map<String, dynamic>>();
  }

  /// Get user growth data (daily signups)
  Future<List<Map<String, dynamic>>> getUserGrowth({
    required DateTime from,
    required DateTime to,
  }) async {
    final data = await _supabase
        .from('profiles')
        .select('created_at')
        .gte('created_at', from.toIso8601String())
        .lte('created_at', to.toIso8601String())
        .eq('role', 'student')
        .order('created_at');

    return (data as List).cast<Map<String, dynamic>>();
  }

  /// Get question attempt distribution (by score ranges)
  Future<Map<String, int>> getScoreDistribution() async {
    final data = await _supabase
        .from('user_question_attempts')
        .select('score')
        .not('score', 'is', null);

    final distribution = <String, int>{
      '0-20': 0,
      '21-40': 0,
      '41-60': 0,
      '61-80': 0,
      '81-100': 0,
    };

    for (final row in data as List) {
      final score = row['score'] as int;
      if (score <= 20) {
        distribution['0-20'] = distribution['0-20']! + 1;
      } else if (score <= 40) {
        distribution['21-40'] = distribution['21-40']! + 1;
      } else if (score <= 60) {
        distribution['41-60'] = distribution['41-60']! + 1;
      } else if (score <= 80) {
        distribution['61-80'] = distribution['61-80']! + 1;
      } else {
        distribution['81-100'] = distribution['81-100']! + 1;
      }
    }

    return distribution;
  }

  /// Log admin activity
  Future<void> logActivity({
    required String actionType,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? details,
  }) async {
    await _supabase.rpc('log_admin_activity', params: {
      'p_action_type': actionType,
      'p_entity_type': entityType,
      'p_entity_id': entityId,
      'p_details': details,
    });
  }

  Map<String, dynamic> _getDefaultAnalytics() {
    return {
      'total_users': 0,
      'active_users_7d': 0,
      'active_users_30d': 0,
      'total_questions': 0,
      'total_attempts': 0,
      'avg_platform_score': 0.0,
      'total_bookmarks': 0,
      'total_notes': 0,
    };
  }
}
