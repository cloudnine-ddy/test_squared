/// Model representing a past paper
class PaperModel {
  final String id;
  final String subjectId;
  final int year;
  final String season; // 'May/June', 'Oct/Nov'
  final int variant;
  final int? paperNumber;
  final String paperType; // 'objective' or 'subjective'

  const PaperModel({
    required this.id,
    required this.subjectId,
    required this.year,
    required this.season,
    required this.variant,
    this.paperNumber,
    required this.paperType,
  });

  /// Display name (e.g., "Paper 1 Variant 1")
  String get displayName {
    final num = paperNumber != null ? 'Paper $paperNumber ' : '';
    return '${num}Variant $variant';
  }

  factory PaperModel.fromMap(Map<String, dynamic> map) {
    return PaperModel(
      id: map['id']?.toString() ?? '',
      subjectId: map['subject_id']?.toString() ?? '',
      year: map['year'] as int? ?? 0,
      season: map['season']?.toString() ?? '',
      variant: map['variant'] as int? ?? 1,
      paperNumber: map['paper_number'] as int?,
      paperType: map['paper_type']?.toString() ?? 'subjective',
    );
  }
}
