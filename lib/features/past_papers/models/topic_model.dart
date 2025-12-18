import 'package:flutter/material.dart';

class TopicModel {
  final String id;
  final String name;
  final String description;
  final int questionCount;
  final Color color;

  const TopicModel({
    required this.id,
    required this.name,
    required this.description,
    required this.questionCount,
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
      description: map['description'] as String? ?? '',
      questionCount: map['question_count'] as int? ?? map['questionCount'] as int? ?? 0,
      color: colorValue,
    );
  }

  // Convert to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'question_count': questionCount,
      'color': color.value,
    };
  }
}

