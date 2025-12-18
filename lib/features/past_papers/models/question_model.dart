class QuestionModel {
  final String id; // UUID
  final String? paperId; // Foreign Key to Papers (nullable)
  final List<String> topicIds; // List of IDs to support multi-tagging
  final int questionNumber;
  final String content;
  final String officialAnswer;
  final List<Map<String, dynamic>> aiAnswer; // JSONB step-by-step guide

  const QuestionModel({
    required this.id,
    this.paperId,
    required this.topicIds,
    required this.questionNumber,
    required this.content,
    required this.officialAnswer,
    required this.aiAnswer,
  });

  // Helper getter to check if AI answer exists
  bool get hasAiAnswer => aiAnswer.isNotEmpty;

  // Convert to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'paper_id': paperId,
      'topic_ids': topicIds,
      'question_number': questionNumber,
      'content': content,
      'official_answer': officialAnswer,
      'ai_answer': aiAnswer,
    };
  }

  // Create from Map (e.g., from database) - Extremely defensive
  factory QuestionModel.fromMap(Map<String, dynamic> map) {
    // Handle id safely - default to empty string if null
    final id = map['id']?.toString() ?? '';
    
    // Handle paperId safely - nullable
    final paperId = map['paper_id']?.toString();
    
    // Handle content safely - default to 'No content' if null
    final content = map['content']?.toString() ?? 'No content';
    
    // Handle officialAnswer safely - default to empty string if null
    final officialAnswer = map['official_answer']?.toString() ?? 
                          map['officialAnswer']?.toString() ?? '';
    
    // Handle questionNumber safely - default to 0 if null
    final questionNumber = map['question_number'] as int? ?? 
                          map['questionNumber'] as int? ?? 0;
    
    // Handle topicIds safely - if null, return empty list, otherwise cast safely
    List<String> topicIds = [];
    final topicIdsRaw = map['topic_ids'] ?? map['topicIds'];
    if (topicIdsRaw != null) {
      if (topicIdsRaw is List) {
        try {
          topicIds = topicIdsRaw
              .map((e) => e.toString())
              .toList();
        } catch (e) {
          print('WARNING: Failed to parse topicIds: $e');
          topicIds = [];
        }
      }
    }
    
    // Handle aiAnswer safely - if null, return empty list, otherwise cast safely
    List<Map<String, dynamic>> aiAnswer = [];
    final aiAnswerRaw = map['ai_answer'] ?? map['aiAnswer'];
    if (aiAnswerRaw != null) {
      if (aiAnswerRaw is List) {
        try {
          aiAnswer = aiAnswerRaw
              .where((item) => item is Map<String, dynamic>)
              .map((item) => item as Map<String, dynamic>)
              .toList();
        } catch (e) {
          print('WARNING: Failed to parse aiAnswer: $e');
          aiAnswer = [];
        }
      }
    }
    
    return QuestionModel(
      id: id,
      paperId: paperId,
      topicIds: topicIds,
      questionNumber: questionNumber,
      content: content,
      officialAnswer: officialAnswer,
      aiAnswer: aiAnswer,
    );
  }

  // Create a copy with optional field updates
  QuestionModel copyWith({
    String? id,
    String? paperId,
    List<String>? topicIds,
    int? questionNumber,
    String? content,
    String? officialAnswer,
    List<Map<String, dynamic>>? aiAnswer,
  }) {
    return QuestionModel(
      id: id ?? this.id,
      paperId: paperId ?? this.paperId,
      topicIds: topicIds ?? this.topicIds,
      questionNumber: questionNumber ?? this.questionNumber,
      content: content ?? this.content,
      officialAnswer: officialAnswer ?? this.officialAnswer,
      aiAnswer: aiAnswer ?? this.aiAnswer,
    );
  }
}

