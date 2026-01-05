// progress_repository.dart
// Add this method to your existing ProgressRepository class

/// Get questions with the user's latest attempt for each question
Future<List<Map<String, dynamic>>> getQuestionsWithAttempts({
  required String userId,
  String? paperId,
  List<String>? topicIds,
  int? limit,
}) async {
  var query = _supabase
      .from('questions')
      .select('''
        *,
        papers(*),
        user_question_attempts!left(
          id,
          score,
          is_correct,
          attempted_at,
          answer_text,
          selected_option
        )
      ''')
      .eq('user_question_attempts.user_id', userId)
      .order('attempted_at',
        foreignTable: 'user_question_attempts',
        ascending: false
      );

  if (paperId != null) {
    query = query.eq('paper_id', paperId);
  }

  if (topicIds != null && topicIds.isNotEmpty) {
    query = query.overlaps('topic_ids', topicIds);
  }

  if (limit != null) {
    query = query.limit(limit);
  }

  final data = await query;

  // Process the data to get only the latest attempt per question
  return (data as List).map((questionData) {
    final attempts = questionData['user_question_attempts'] as List?;
    final latestAttempt = (attempts != null && attempts.isNotEmpty)
        ? attempts.first
        : null;

    return {
      ...questionData,
      'latest_attempt': latestAttempt,
    };
  }).toList();
}
