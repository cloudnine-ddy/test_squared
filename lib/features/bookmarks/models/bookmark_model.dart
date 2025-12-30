class BookmarkModel {
  final String id;
  final String userId;
  final String questionId;
  final String folderName;
  final DateTime createdAt;

  const BookmarkModel({
    required this.id,
    required this.userId,
    required this.questionId,
    required this.folderName,
    required this.createdAt,
  });

  factory BookmarkModel.fromMap(Map<String, dynamic> map) {
    return BookmarkModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      questionId: map['question_id']?.toString() ?? '',
      folderName: map['folder_name']?.toString() ?? 'My Bookmarks',
      createdAt: map['created_at'] is String
          ? DateTime.parse(map['created_at'])
          : map['created_at'] as DateTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'question_id': questionId,
      'folder_name': folderName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  BookmarkModel copyWith({
    String? id,
    String? userId,
    String? questionId,
    String? folderName,
    DateTime? createdAt,
  }) {
    return BookmarkModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      questionId: questionId ?? this.questionId,
      folderName: folderName ?? this.folderName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
