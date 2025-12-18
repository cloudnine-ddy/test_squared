import 'package:flutter/material.dart';

class TopicModel {
  final String id;
  final String title;
  final String description;
  final int questionCount;
  final Color color;

  const TopicModel({
    required this.id,
    required this.title,
    required this.description,
    required this.questionCount,
    required this.color,
  });
}

