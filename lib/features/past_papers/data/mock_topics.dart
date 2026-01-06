import 'package:flutter/material.dart';
import '../models/topic_model.dart';

const kMockTopics = [
  TopicModel(
    id: '1',
    name: 'Algebra',
    subjectId: 'mock_math_subject',
    description: 'Linear & Quadratic equations',
    questionCount: 120,
    color: Colors.blue,
  ),
  TopicModel(
    id: '2',
    name: 'Geometry',
    subjectId: 'mock_math_subject',
    description: 'Shapes, angles, and spatial relationships',
    questionCount: 95,
    color: Colors.green,
  ),
  TopicModel(
    id: '3',
    name: 'Trigonometry',
    subjectId: 'mock_math_subject',
    description: 'Sine, cosine, and tangent functions',
    questionCount: 85,
    color: Colors.orange,
  ),
  TopicModel(
    id: '4',
    name: 'Calculus',
    subjectId: 'mock_math_subject',
    description: 'Derivatives and integrals',
    questionCount: 150,
    color: Colors.red,
  ),
  TopicModel(
    id: '5',
    name: 'Statistics',
    subjectId: 'mock_math_subject',
    description: 'Data analysis and probability',
    questionCount: 110,
    color: Colors.purple,
  ),
];

