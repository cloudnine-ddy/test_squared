import 'package:flutter/material.dart';
import '../models/topic_model.dart';

const kMockTopics = [
  TopicModel(
    id: '1',
    name: 'Algebra',
    description: 'Linear & Quadratic equations',
    questionCount: 120,
    color: Colors.blue,
  ),
  TopicModel(
    id: '2',
    name: 'Geometry',
    description: 'Shapes, angles, and spatial relationships',
    questionCount: 95,
    color: Colors.green,
  ),
  TopicModel(
    id: '3',
    name: 'Trigonometry',
    description: 'Sine, cosine, and tangent functions',
    questionCount: 85,
    color: Colors.orange,
  ),
  TopicModel(
    id: '4',
    name: 'Calculus',
    description: 'Derivatives and integrals',
    questionCount: 150,
    color: Colors.red,
  ),
  TopicModel(
    id: '5',
    name: 'Statistics',
    description: 'Data analysis and probability',
    questionCount: 110,
    color: Colors.purple,
  ),
];

