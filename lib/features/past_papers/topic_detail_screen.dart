import 'package:flutter/material.dart';
import 'data/mock_questions.dart';
import 'widgets/question_card.dart';

class TopicDetailScreen extends StatelessWidget {
  final String topicId;

  const TopicDetailScreen({
    super.key,
    required this.topicId,
  });

  @override
  Widget build(BuildContext context) {
    final filteredQuestions = kMockQuestions
        .where((q) => q.topicIds.contains(topicId))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Topic $topicId'),
      ),
      body: filteredQuestions.isEmpty
          ? const Center(
              child: Text('No questions found for this topic'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredQuestions.length,
              itemBuilder: (context, index) {
                final question = filteredQuestions[index];
                return QuestionCard(question: question);
              },
            ),
    );
  }
}

