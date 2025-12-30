class QuestionAttemptModel {
  final String id;
  final String userId;
  final String questionId;
  final String? answerText;
  final String? selectedOption; // For MCQ: 'A', 'B', 'C', 'D'
  final int? score; // 0-100
  final bool? isCorrect;
  final int timeSpentSeconds;
  final int hintsUsed;
  final DateTime attemptedAt;

  const QuestionAttemptModel({
    required this.id,
    required this.userId,
    required this.questionId,
    this.answerText,
    this.selectedOption,
    this.score,
    this.isCorrect,
    this.timeSpentSeconds = 0,
    this.hintsUsed = 0,
    required this.attemptedAt,
  });

  // Helper getters
  bool get isPass => score != null && score! >= 50;
  double get scorePercentage => score?.toDouble() ?? 0.0;
  String get scoreDisplay => score != null ? '$score%' : 'Not graded';
  
  String get timeSpentDisplay {
    if (timeSpentSeconds < 60) {
      return '${timeSpentSeconds}s';
    } else if (timeSpentSeconds < 3600) {
      final minutes = timeSpentSeconds ~/ 60;
      final seconds = timeSpentSeconds % 60;
      return '${minutes}m ${seconds}s';
    } else {
      final hours = timeSpentSeconds ~/ 3600;
      final minutes = (timeSpentSeconds % 3600) ~/ 60;
      return '${hours}h ${minutes}m';
    }
  }

  factory QuestionAttemptModel.fromMap(Map<String, dynamic> map) {
    return QuestionAttemptModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      questionId: map['question_id']?.toString() ?? '',
      answerText: map['answer_text']?.toString(),
      selectedOption: map['selected_option']?.toString(),
      score: map['score'] as int?,
      isCorrect: map['is_correct'] as bool?,
      timeSpentSeconds: map['time_spent_seconds'] as int? ?? 0,
      hintsUsed: map['hints_used'] as int? ?? 0,
      attemptedAt: map['attempted_at'] is String
          ? DateTime.parse(map['attempted_at'])
          : map['attempted_at'] as DateTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'question_id': questionId,
      'answer_text': answerText,
      'selected_option': selectedOption,
      'score': score,
      'is_correct': isCorrect,
      'time_spent_seconds': timeSpentSeconds,
      'hints_used': hintsUsed,
      'attempted_at': attemptedAt.toIso8601String(),
    };
  }

  QuestionAttemptModel copyWith({
    String? id,
    String? userId,
    String? questionId,
    String? answerText,
    String? selectedOption,
    int? score,
    bool? isCorrect,
    int? timeSpentSeconds,
    int? hintsUsed,
    DateTime? attemptedAt,
  }) {
    return QuestionAttemptModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      questionId: questionId ?? this.questionId,
      answerText: answerText ?? this.answerText,
      selectedOption: selectedOption ?? this.selectedOption,
      score: score ?? this.score,
      isCorrect: isCorrect ?? this.isCorrect,
      timeSpentSeconds: timeSpentSeconds ?? this.timeSpentSeconds,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      attemptedAt: attemptedAt ?? this.attemptedAt,
    );
  }
}
