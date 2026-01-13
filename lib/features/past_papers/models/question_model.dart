import 'question_blocks.dart';

class QuestionModel {
  final String id;
  final String? paperId;
  final List<String> topicIds;
  final int questionNumber;
  final String content;
  final String officialAnswer;
  final String? imageUrl;
  final int? marks;
  final String aiSolution; // Legacy AI steps
  final Map<String, dynamic>? aiAnswerRaw; // Full JSON including boundingBox
  final Map<String, dynamic>? explanationRaw; // New explanation field

  // MCQ-specific fields
  final String type; // 'mcq' or 'structured'
  final List<Map<String, String>>? options; // [{label: 'A', text: '...'}]

  // Structured question fields
  final List<ExamContentBlock>? structureData; // JSONB blocks for structured questions
  final String? correctAnswer; // 'A', 'B', 'C', or 'D'

  // Paper info (joined from papers table)
  final int? paperYear;
  final String? paperSeason;
  final int? paperVariant;
  final String? paperType; // 'objective' or 'subjective'
  final String? pdfUrl;

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
    this.explanationRaw,
    this.type = 'structured',
    this.options,
    this.correctAnswer,
    this.paperYear,
    this.paperSeason,
    this.paperVariant,
    this.paperType,
    this.pdfUrl,
    this.structureData,
  });

  // Helper getters
  bool get hasAiSolution => aiSolution.isNotEmpty || (structureData?.any((b) => b is QuestionPartBlock && (b as QuestionPartBlock).aiAnswer != null) ?? false);

  bool get hasOfficialAnswer {
      if (officialAnswer.isNotEmpty) return true;
      if (isStructured && structureData != null) {
          return structureData!.any((b) => b is QuestionPartBlock && (b as QuestionPartBlock).officialAnswer != null);
      }
      return false;
  }

  bool get hasFigure => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasPaperInfo => paperYear != null && paperSeason != null;
  bool get isMCQ => type == 'mcq';
  bool get isStructured => type == 'structured' && structureData != null && structureData!.isNotEmpty;
  bool get hasOptions => options != null && options!.isNotEmpty;
  bool get hasExplanation => explanationRaw != null || (aiAnswerRaw != null && aiAnswerRaw!.containsKey('explanation')); // Check both location

  /// Returns the total marks for the question.
  /// For structured questions, sums the marks of individual parts dynamically
  /// to ensure accuracy even if the database marks column is incorrect.
  int get totalMarks {
    if (isStructured && structureData != null) {
      int sum = 0;
      for (final block in structureData!) {
        if (block is QuestionPartBlock) {
          sum += block.marks;
        }
      }
      if (sum > 0) return sum;
    }
    return marks ?? 0;
  }

  /// Returns the AI answer text string for display
  String? get aiAnswer {
    // Try to get from aiAnswerRaw.text first (preferred format)
    if (aiAnswerRaw != null && aiAnswerRaw!['text'] != null) {
      return aiAnswerRaw!['text'].toString();
    }
    // Fallback: if aiAnswerRaw exists but has no text field, convert entire JSON to string for now
    if (aiAnswerRaw != null) {
      return aiAnswerRaw.toString();
    }
    // Last fallback to aiSolution if available
    if (aiSolution.isNotEmpty) {
      return aiSolution;
    }
    return null;
  }

  /// Returns the static explanation text if available
  String? get explanationText {
    if (explanationRaw != null && explanationRaw!['text'] != null) {
      return explanationRaw!['text'].toString();
    }
    // Fallback if stored inside ai_answer in old format (unlikely after migration but good safety)
    if (aiAnswerRaw != null && aiAnswerRaw!['explanation'] != null) {
      return aiAnswerRaw!['explanation'].toString();
    }
    return null;
  }

  /// Returns the bounding box map {x, y, width, height, page_width...} if available
  Map<String, dynamic>? get boundingBoxMap {
    if (aiAnswerRaw != null && aiAnswerRaw!.containsKey('boundingBox')) {
      return aiAnswerRaw!['boundingBox'];
    }
    // Backward compatibility for old format if needed (skippable for now as we did a clean migration)
    return null;
  }

  /// Gets the correct answer for MCQ - uses correctAnswer if available,
  /// otherwise falls back to parsing first letter from officialAnswer
  String? get effectiveCorrectAnswer {
    if (correctAnswer != null && correctAnswer!.isNotEmpty) {
      return correctAnswer;
    }
    // Fallback: try to get first letter from officialAnswer (e.g., "A", "B")
    if (officialAnswer.isNotEmpty) {
      final firstChar = officialAnswer.trim().toUpperCase();
      if (firstChar.isNotEmpty && 'ABCD'.contains(firstChar[0])) {
        return firstChar[0];
      }
    }
    return null;
  }


  /// Returns the official answer text to display (aggregates structured parts if needed)
  String get formattedOfficialAnswer {
    if (officialAnswer.isNotEmpty) return officialAnswer;

    if (isStructured && structureData != null) {
        final buffer = StringBuffer();
        for (final block in structureData!) {
            if (block is QuestionPartBlock && block.officialAnswer != null && block.officialAnswer!.isNotEmpty) {
                buffer.writeln('${block.label}) ${block.officialAnswer}');
            }
        }
        if (buffer.isNotEmpty) return buffer.toString();
    }

    return 'Answer not available';
  }

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
        // Handle legacy array format if exists
        final steps = aiAnswerData
            .whereType<Map<String, dynamic>>()
            .map((step) => step['description']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        aiSolution = steps.join('\n');
      }
    }

    // Handle new explanation column
    Map<String, dynamic>? explanationRaw;
    final explanationData = map['explanation'];
    if (explanationData != null && explanationData is Map<String, dynamic>) {
      explanationRaw = explanationData;
    } else if (explanationData is String) {
        // If somehow text is stored directly
        explanationRaw = {'text': explanationData};
    }

    // Read marks from proper column first, fallback to ai_answer.marks for old data
    int? marks = map['marks'] as int?;
    if (marks == null && aiAnswerRaw != null) {
      marks = aiAnswerRaw['marks'] as int?;
    }

    // MCQ fields
    final type = map['type']?.toString() ?? 'structured';
    final correctAnswer = map['correct_answer']?.toString();

    // Parse options array
    List<Map<String, String>>? options;
    final optionsRaw = map['options'];
    if (optionsRaw != null && optionsRaw is List) {
      options = optionsRaw.map((o) {
        if (o is Map) {
          return {
            'label': o['label']?.toString() ?? '',
            'text': o['text']?.toString() ?? '',
          };
        }
        return {'label': '', 'text': ''};
      }).toList();
    }

    // Paper type from joined papers table
    String? paperType;
    String? pdfUrl; // Extracted from paperData

    if (paperData is Map<String, dynamic>) {
      paperType = paperData['paper_type']?.toString();
      pdfUrl = paperData['pdf_url']?.toString();
    }

    // Parse structure_data for structured questions
    List<ExamContentBlock>? structureData;
    final structureDataRaw = map['structure_data'];
    if (structureDataRaw != null && structureDataRaw is List) {
      try {
        structureData = structureDataRaw
            .whereType<Map<String, dynamic>>()
            .map((blockMap) => ExamContentBlock.fromMap(blockMap))
            .toList();
      } catch (e) {
        print('Error parsing structure_data: $e');
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
      explanationRaw: explanationRaw,
      type: type,
      options: options,
      correctAnswer: correctAnswer,
      paperYear: paperYear,
      paperSeason: paperSeason,
      paperVariant: paperVariant,
      paperType: paperType,
      pdfUrl: pdfUrl,
      structureData: structureData,
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
      'explanation': explanationRaw,
      'type': type,
      'structure_data': structureData?.map((block) => block.toMap()).toList(),
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
    String? pdfUrl,
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
      explanationRaw: explanationRaw,
      paperYear: paperYear ?? this.paperYear,
      paperSeason: paperSeason ?? this.paperSeason,
      paperVariant: paperVariant ?? this.paperVariant,
      paperType: paperType,
      pdfUrl: pdfUrl ?? this.pdfUrl,
    );
  }
}
