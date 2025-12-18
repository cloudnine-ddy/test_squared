import 'package:flutter/material.dart';
import '../models/question_model.dart';

class QuestionCard extends StatefulWidget {
  final QuestionModel question;

  const QuestionCard({
    super.key,
    required this.question,
  });

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question ${widget.question.questionNumber}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.question.content,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: const Text('5 marks'),
                  backgroundColor: Colors.blue[50],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            // Bottom Section - Solution Toggle
            ExpansionTile(
              title: Text(
                widget.question.hasAiAnswer
                    ? 'Show Solution (${widget.question.aiAnswer.length} steps)'
                    : 'Show Solution',
              ),
              leading: Icon(
                widget.question.hasAiAnswer
                    ? Icons.lightbulb_outline
                    : Icons.info_outline,
                color: widget.question.hasAiAnswer
                    ? Colors.amber[700]
                    : Colors.grey,
              ),
              initiallyExpanded: _isExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  _isExpanded = expanded;
                });
              },
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: widget.question.hasAiAnswer
                      ? _buildSolutionSteps()
                      : const Text(
                          'No solution available yet',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSolutionSteps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.question.aiAnswer.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final stepNumber = step['step'] as int? ?? (index + 1);
        final description = step['description'] as String? ?? '';
        final equation = step['equation'] as String?;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step number indicator
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$stepNumber',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Step content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step $stepNumber',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (description.isNotEmpty)
                      Text(
                        description,
                        style: const TextStyle(fontSize: 14),
                      ),
                    if (equation != null && equation.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          equation,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

