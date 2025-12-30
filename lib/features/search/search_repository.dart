import 'package:supabase_flutter/supabase_flutter.dart';
import '../past_papers/models/question_model.dart';

class SearchRepository {
  final _supabase = Supabase.instance.client;

  /// Search questions with full-text search and filters
  Future<List<QuestionModel>> searchQuestions({
    required String query,
    String? subjectId,
    String? topicId,
    int? year,
    String? season,
    String? questionType, // 'mcq' or 'structured'
    int limit = 20,
    int offset = 0,
  }) async {
    // For subject/year/season, we need to filter via papers first
    List<String>? paperIds;
    if (subjectId != null || year != null || season != null) {
      var paperQuery = _supabase.from('papers').select('id');
      
      if (subjectId != null) {
        paperQuery = paperQuery.eq('subject_id', subjectId);
      }
      if (year != null) {
        paperQuery = paperQuery.eq('year', year);
      }
      if (season != null) {
        paperQuery = paperQuery.eq('season', season);
      }

      final paperData = await paperQuery;
      paperIds = (paperData as List)
          .map((p) => p['id'] as String)
          .toList();

      if (paperIds.isEmpty) {
        return [];
      }
    }

    var dbQuery = _supabase
        .from('questions')
        .select('*, papers(*)')
        .textSearch('search_vector', query, config: 'english');

    // Apply filters
    if (questionType != null) {
      dbQuery = dbQuery.eq('type', questionType);
    }

    if (topicId != null) {
      dbQuery = dbQuery.contains('topic_ids', [topicId]);
    }

    if (paperIds != null) {
      dbQuery = dbQuery.inFilter('paper_id', paperIds);
    }

    final data = await dbQuery
        .order('question_number')
        .range(offset, offset + limit - 1);

    return (data as List).map((json) => QuestionModel.fromMap(json)).toList();
  }

  /// Simple search without filters (for autocomplete)
  Future<List<QuestionModel>> quickSearch(String query, {int limit = 10}) async {
    if (query.trim().isEmpty) return [];

    final data = await _supabase
        .from('questions')
        .select('*, papers(*)')
        .textSearch('search_vector', query, config: 'english')
        .limit(limit);

    return (data as List).map((json) => QuestionModel.fromMap(json)).toList();
  }

  /// Get recent searches for current user (stored locally, not in DB)
  List<String> getRecentSearches() {
    // TODO: Implement local storage
    return [];
  }

  /// Save search query (stored locally)
  void saveSearch(String query) {
    // TODO: Implement local storage
  }

  /// Clear recent searches
  void clearRecentSearches() {
    // TODO: Implement local storage
  }
}
