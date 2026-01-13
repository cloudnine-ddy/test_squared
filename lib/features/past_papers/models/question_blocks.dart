/// Block-based data structures for Smart Question Rendering
/// Schema: text, figure, question_part

abstract class ExamContentBlock {
  final String type;

  const ExamContentBlock({required this.type});

  Map<String, dynamic> toMap();

  factory ExamContentBlock.fromMap(Map<String, dynamic> map) {
    final type = map['type']?.toString() ?? '';

    switch (type) {
      case 'text':
        return TextBlock.fromMap(map);
      case 'figure':
        return FigureBlock.fromMap(map);
      case 'question_part':
        return QuestionPartBlock.fromMap(map);
      // Fallback for legacy types if needed, or default to text
      case 'image': // Legacy mapping
        return FigureBlock.fromMap({'type': 'figure', 'url': map['url'], 'description': map['caption']});
      case 'sub_question': // Legacy mapping
        return QuestionPartBlock.fromMap({'type': 'question_part', 'label': map['id'], 'content': map['text'], ...map});
      default:
        // Graceful fallback for unknown types
        return TextBlock(content: 'Unknown block type: $type');
    }
  }
}

/// A standard block of text
class TextBlock extends ExamContentBlock {
  final String content;

  const TextBlock({required this.content}) : super(type: 'text');

  factory TextBlock.fromMap(Map<String, dynamic> map) {
    return TextBlock(
      content: map['content']?.toString() ?? '',
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'content': content,
    };
  }
}

/// A figure/image block with a label and description
class FigureBlock extends ExamContentBlock {
  final String? url; // URL might be populated after upload or from scraping
  final String figureLabel; // e.g., "Figure 1"
  final String description; // e.g., "A ramp with angle 30..."
  final Map<String, dynamic>? meta; // For storing bounding boxes or other coordinates

  const FigureBlock({
    this.url,
    required this.figureLabel,
    required this.description,
    this.meta,
  }) : super(type: 'figure');

  factory FigureBlock.fromMap(Map<String, dynamic> map) {
    // Capture metadata like page and bbox which might be at root level
    final meta = map['meta'] as Map<String, dynamic>? ?? {};
    if (map['page'] != null) meta['page'] = map['page'];
    if (map['bbox'] != null) meta['bbox'] = map['bbox'];

    return FigureBlock(
      url: map['url']?.toString(),
      figureLabel: map['figure_label']?.toString() ?? 'Figure',
      description: map['description']?.toString() ?? '',
      meta: meta.isNotEmpty ? meta : null,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      if (url != null) 'url': url,
      'figure_label': figureLabel,
      'description': description,
      if (meta != null) 'meta': meta,
    };
  }
}

/// A specific question part (e.g., "a)", "b)(i)")
class QuestionPartBlock extends ExamContentBlock {
  final String label; // e.g., "a)", "b)"
  final String content; // The question text: "Calculate the force..."
  final int marks;
  final String inputType; // 'fill_in_blanks', 'text_area', 'mcq'
  final dynamic correctAnswer;
  final List<String>? options; // For MCQ parts
  final String? officialAnswer;
  final String? aiAnswer;

  const QuestionPartBlock({
    required this.label,
    required this.content,
    required this.marks,
    this.inputType = 'text_area',
    this.correctAnswer,
    this.options,
    this.officialAnswer,
    this.aiAnswer,
  }) : super(type: 'question_part');

  factory QuestionPartBlock.fromMap(Map<String, dynamic> map) {
    return QuestionPartBlock(
      label: map['label']?.toString() ?? map['id']?.toString() ?? '?',
      content: map['content']?.toString() ?? map['text']?.toString() ?? '',
      marks: int.tryParse(map['marks']?.toString() ?? '1') ?? 1,
      inputType: map['input_type']?.toString() ?? 'text_area',
      correctAnswer: map['correct_answer'],
      options: map['options'] != null
          ? List<String>.from(map['options'] as List)
          : null,
      officialAnswer: map['official_answer']?.toString(),
      aiAnswer: map['ai_answer']?.toString() ?? map['explanation']?.toString() ?? map['ai_explanation']?.toString(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'label': label,
      'content': content,
      'marks': marks,
      'input_type': inputType,
      'correct_answer': correctAnswer,
      if (options != null) 'options': options,
      if (officialAnswer != null) 'official_answer': officialAnswer,
      if (aiAnswer != null) 'ai_answer': aiAnswer,
    };
  }
}
