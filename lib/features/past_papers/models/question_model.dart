class QuestionModel {
  final String id;
  final String? paperId;
  final List<String> topicIds;
  final int questionNumber;
  final String content;
  final String officialAnswer;
  final String? imageUrl;
  final int? marks;
  final String aiSolution;
  final Map<String, dynamic>? aiAnswerRaw;

  // Paper info (joined from papers table)
  final int? paperYear;
  final String? paperSeason;
  final int? paperVariant;

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
    this.paperYear,
    this.paperSeason,
    this.paperVariant,
  });

  // Helper getters
  bool get hasAiSolution => aiSolution.isNotEmpty;
  bool get hasOfficialAnswer => officialAnswer.isNotEmpty;
  bool get hasFigure => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasPaperInfo => paperYear != null && paperSeason != null;

  String get paperLabel {
    if (!hasPaperInfo) return '';
    final season = paperSeason!.substring(0, 1).toUpperCase() + paperSeason!.substring(1);
    return '$paperYear $season${paperVariant != null ? " V$paperVariant" : ""}';
  }

  factory QuestionModel.fromMap(Map<String, dynamic> map) {
    final id = map['id']?.toString() ?? '';
    final paperId = map['paper_id']?.toString();
    final content = map['content']?.toString() ?? 'No content';
    final officialAnswer = map['official_answer']?.toString() ?? '';
    final questionNumber = map['question_number'] as int? ?? 0;
    final imageUrl = map['image_url']?.toString();

    // Paper info from joined papers table
    int? paperYear;
    String? paperSeason;
    int? paperVariant;
    final paperData = map['papers'];
    if (paperData is Map<String, dynamic>) {
      paperYear = paperData['year'] as int?;
      paperSeason = paperData['season']?.toString();
      paperVariant = paperData['variant'] as int?;
    }

    // Handle topicIds
    List<String> topicIds = [];
    final topicIdsRaw = map['topic_ids'] ?? map['topicIds'];
    if (topicIdsRaw != null && topicIdsRaw is List) {
      topicIds = topicIdsRaw.map((e) => e.toString()).toList();
    }

    // Handle ai_answer
    String aiSolution = '';
    Map<String, dynamic>? aiAnswerRaw;

    final aiAnswerData = map['ai_answer'] ?? map['aiAnswer'];
    if (aiAnswerData != null) {
      if (aiAnswerData is Map<String, dynamic>) {
        aiAnswerRaw = aiAnswerData;
        // Check 'text' first as per new requirement, then fallback to 'ai_solution'
        aiSolution = aiAnswerData['text']?.toString() ?? aiAnswerData['ai_solution']?.toString() ?? '';
      } else if (aiAnswerData is List && aiAnswerData.isNotEmpty) {
        final steps = aiAnswerData
            .whereType<Map<String, dynamic>>()
            .map((step) => step['description']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        aiSolution = steps.join('\n');
      }
    }

    // Read marks from proper column first, fallback to ai_answer.marks for old data
    int? marks = map['marks'] as int?;
    if (marks == null && aiAnswerRaw != null) {
      marks = aiAnswerRaw['marks'] as int?;
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
      paperYear: paperYear,
      paperSeason: paperSeason,
      paperVariant: paperVariant,
    );
  }

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
    int? paperYear,
    String? paperSeason,
    int? paperVariant,
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
      paperYear: paperYear ?? this.paperYear,
      paperSeason: paperSeason ?? this.paperSeason,
      paperVariant: paperVariant ?? this.paperVariant,
    );
  }
}
