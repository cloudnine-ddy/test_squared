class QuestionModel {
  final String id;
  final String? paperId;
  final List<String> topicIds;
  final int questionNumber;
  final String content;
  final String officialAnswer;
  final String? imageUrl;
  final int? marks;
  final String aiSolution; // AI-generated step-by-step solution (text)
  final Map<String, dynamic>? aiAnswerRaw; // Raw ai_answer from DB

  const QuestionModel({
    required this.id,
    this.paperId,
    required this.topicIds,
    required this.questionNumber,
    required this.content,
    required this.officialAnswer,
    this.imageUrl,
    this.marks,
    required this.aiSolution,
    this.aiAnswerRaw,
  });

  // Helper getter to check if AI solution exists
  bool get hasAiSolution => aiSolution.isNotEmpty;
  
  // Helper getter to check if official answer exists
  bool get hasOfficialAnswer => officialAnswer.isNotEmpty;
  
  // Helper getter to check if figure exists
  bool get hasFigure => imageUrl != null && imageUrl!.isNotEmpty;

  // Create from Map (e.g., from database)
  factory QuestionModel.fromMap(Map<String, dynamic> map) {
    final id = map['id']?.toString() ?? '';
    final paperId = map['paper_id']?.toString();
    final content = map['content']?.toString() ?? 'No content';
    final officialAnswer = map['official_answer']?.toString() ?? 
                          map['officialAnswer']?.toString() ?? '';
    final questionNumber = map['question_number'] as int? ?? 
                          map['questionNumber'] as int? ?? 0;
    final imageUrl = map['image_url']?.toString();
    
    // Handle topicIds
    List<String> topicIds = [];
    final topicIdsRaw = map['topic_ids'] ?? map['topicIds'];
    if (topicIdsRaw != null && topicIdsRaw is List) {
      topicIds = topicIdsRaw.map((e) => e.toString()).toList();
    }
    
    // Handle ai_answer - can be Map with ai_solution string, or List (old format)
    String aiSolution = '';
    int? marks;
    Map<String, dynamic>? aiAnswerRaw;
    
    final aiAnswerData = map['ai_answer'] ?? map['aiAnswer'];
    if (aiAnswerData != null) {
      if (aiAnswerData is Map<String, dynamic>) {
        aiAnswerRaw = aiAnswerData;
        // New format: {ai_solution: "...", marks: 5}
        aiSolution = aiAnswerData['ai_solution']?.toString() ?? '';
        marks = aiAnswerData['marks'] as int?;
      } else if (aiAnswerData is List && aiAnswerData.isNotEmpty) {
        // Old format: List of step objects - convert to text
        final steps = aiAnswerData
            .whereType<Map<String, dynamic>>()
            .map((step) => step['description']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        aiSolution = steps.join('\n');
      }
    }
    
    return QuestionModel(
      id: id,
      paperId: paperId,
      topicIds: topicIds,
      questionNumber: questionNumber,
      content: content,
      officialAnswer: officialAnswer,
      imageUrl: imageUrl,
      marks: marks,
      aiSolution: aiSolution,
      aiAnswerRaw: aiAnswerRaw,
    );
  }

  // Convert to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'paper_id': paperId,
      'topic_ids': topicIds,
      'question_number': questionNumber,
      'content': content,
      'official_answer': officialAnswer,
      'image_url': imageUrl,
      'ai_answer': aiAnswerRaw,
    };
  }

  // Create a copy with optional field updates
  QuestionModel copyWith({
    String? id,
    String? paperId,
    List<String>? topicIds,
    int? questionNumber,
    String? content,
    String? officialAnswer,
    String? imageUrl,
    int? marks,
    String? aiSolution,
  }) {
    return QuestionModel(
      id: id ?? this.id,
      paperId: paperId ?? this.paperId,
      topicIds: topicIds ?? this.topicIds,
      questionNumber: questionNumber ?? this.questionNumber,
      content: content ?? this.content,
      officialAnswer: officialAnswer ?? this.officialAnswer,
      imageUrl: imageUrl ?? this.imageUrl,
      marks: marks ?? this.marks,
      aiSolution: aiSolution ?? this.aiSolution,
      aiAnswerRaw: aiAnswerRaw,
    );
  }
}
