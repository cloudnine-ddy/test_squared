// Example: Updated Question Card Widget with Progress Indicators

import 'package:flutter/material.dart';
import '../utils/question_status_helper.dart';

class QuestionCardWithProgress extends StatelessWidget {
  final Map<String, dynamic> questionData;
  final VoidCallback onTap;

  const QuestionCardWithProgress({
    Key? key,
    required this.questionData,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final latestAttempt = questionData['latest_attempt'] as Map<String, dynamic>?;
    final statusColor = QuestionStatusHelper.getStatusColor(latestAttempt);
    final statusIcon = QuestionStatusHelper.getStatusIcon(latestAttempt);
    final questionNumber = questionData['question_number'];
    final marks = questionData['marks'];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: statusColor, // Status-based border color
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Question number badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'Q$questionNumber',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Question content (truncated)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    questionData['content'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Status indicator
                  Row(
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        QuestionStatusHelper.getStatusText(latestAttempt),
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Marks badge with status icon
            if (marks != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber.shade700),
                    const SizedBox(width: 4),
                    Text(
                      '$marks marks',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
