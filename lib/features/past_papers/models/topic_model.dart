import 'package:flutter/material.dart';

class TopicModel {
  final String id;
  final String name;
  final String subjectId;
  final String description;
  final int questionCount;
  final int mcqCount;
  final int structuredCount;
  final Color color;

  const TopicModel({
    required this.id,
    required this.name,
    required this.subjectId,
    required this.description,
    required this.questionCount,
    this.mcqCount = 0,
    this.structuredCount = 0,
    required this.color,
  });

  // Create from Map (e.g., from database)
  factory TopicModel.fromMap(Map<String, dynamic> map) {
    // Handle color - assuming it's stored as an int (ARGB) or hex string
    Color colorValue;
    if (map['color'] is int) {
      colorValue = Color(map['color'] as int);
    } else if (map['color'] is String) {
      // Handle hex string like '#FF0000' or 'FF0000'
      final colorString = (map['color'] as String).replaceAll('#', '');
      colorValue = Color(int.parse(colorString, radix: 16) + 0xFF000000);
    } else {
      // Default to blue if color is missing or invalid
      colorValue = Colors.blue;
    }

    return TopicModel(
      id: map['id'] as String,
      name: map['name'] as String,
      subjectId: map['subject_id'] as String? ?? '',
      description: map['description'] as String? ?? '',
      questionCount: map['question_count'] as int? ?? map['questionCount'] as int? ?? 0,
      mcqCount: map['mcq_count'] as int? ?? 0,
      structuredCount: map['structured_count'] as int? ?? 0,
      color: colorValue,
    );
  }

  // Convert to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'subject_id': subjectId,
      'description': description,
      'question_count': questionCount,
      'mcq_count': mcqCount,
      'structured_count': structuredCount,
      'color': color.value,
    };
  }
}

