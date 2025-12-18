class QuestionModel {
  final String id; // UUID
  final String paperId; // Foreign Key to Papers
  final List<String> topicIds; // List of IDs to support multi-tagging
  final int questionNumber;
  final String content;
  final String officialAnswer;
  final List<Map<String, dynamic>> aiAnswer; // JSONB step-by-step guide

  const QuestionModel({
    required this.id,
    required this.paperId,
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
      'paperId': paperId,
      'topicIds': topicIds,
      'questionNumber': questionNumber,
      'content': content,
      'officialAnswer': officialAnswer,
      'aiAnswer': aiAnswer,
    };
  }

  // Create from Map (e.g., from database)
  factory QuestionModel.fromMap(Map<String, dynamic> map) {
    return QuestionModel(
      id: map['id'] as String,
      paperId: map['paperId'] as String,
      topicIds: List<String>.from(map['topicIds'] as List),
      questionNumber: map['questionNumber'] as int,
      content: map['content'] as String,
      officialAnswer: map['officialAnswer'] as String,
      aiAnswer: List<Map<String, dynamic>>.from(
        map['aiAnswer'] as List? ?? [],
      ),
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

