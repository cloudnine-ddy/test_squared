class NoteModel {
  final String id;
  final String userId;
  final String questionId;
  final String noteText;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NoteModel({
    required this.id,
    required this.userId,
    required this.questionId,
    required this.noteText,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isEdited => updatedAt.isAfter(createdAt.add(const Duration(seconds: 1)));

  String get preview {
    if (noteText.length <= 100) return noteText;
    return '${noteText.substring(0, 100)}...';
  }

  int get wordCount => noteText.trim().split(RegExp(r'\s+')).length;

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      questionId: map['question_id']?.toString() ?? '',
      noteText: map['note_text']?.toString() ?? '',
      createdAt: map['created_at'] is String
          ? DateTime.parse(map['created_at'])
          : map['created_at'] as DateTime,
      updatedAt: map['updated_at'] is String
          ? DateTime.parse(map['updated_at'])
          : map['updated_at'] as DateTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'question_id': questionId,
      'note_text': noteText,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  NoteModel copyWith({
    String? id,
    String? userId,
    String? questionId,
    String? noteText,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      questionId: questionId ?? this.questionId,
      noteText: noteText ?? this.noteText,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
