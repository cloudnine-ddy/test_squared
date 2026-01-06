import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/question_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../progress/utils/question_status_helper.dart';
import 'topic_tags.dart';

/// Simplified MCQ Feed Card that matches QuestionCard (Structured) styling and behavior.
/// Navigates to detail screen on tap instead of inline answering.
class MultipleChoiceFeedCard extends StatelessWidget {
  final QuestionModel question;
  final String? paperName;
  final Map<String, dynamic>? latestAttempt;
  final String? topicId; // Added for navigation context initialization
  final Function(String?)? onAnswerChanged; // Kept for compatibility but unused
  final Function(bool)? onCheckResult;    // Kept for compatibility but unused

  const MultipleChoiceFeedCard({
    super.key,
    required this.question,
    this.paperName,
    this.latestAttempt,
    this.topicId,
    this.onAnswerChanged,
    this.onCheckResult,
  });

  @override
  Widget build(BuildContext context) {
    // Get status color and icon from helper
    final statusColor = QuestionStatusHelper.getStatusColor(latestAttempt);
    final statusIcon = QuestionStatusHelper.getStatusIcon(latestAttempt);
    final hasAttempt = latestAttempt != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).cardTheme.color
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasAttempt
              ? statusColor.withValues(alpha: 0.5)
              : (Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).dividerColor
                  : AppColors.border.withValues(alpha: 0.5)),
          width: hasAttempt ? 2 : 1,
        ),
        // Add subtle glow for attempted questions
        boxShadow: hasAttempt ? [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            // Navigate to question detail with topic context
            final uri = Uri(
              path: '/question/${question.id}',
              queryParameters: topicId != null ? {'topicId': topicId} : null,
            );
            await context.push(uri.toString());
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question content - The hero element
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question number indicator
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${question.questionNumber}',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Question text (Preview)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            question.content,
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Theme.of(context).colorScheme.onSurface
                                  : AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Metadata footer
                Row(
                  children: [
                    // Type indicator
                    Icon(
                      Icons.radio_button_checked,
                      size: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'MCQ',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    // Divider
                    if (paperName != null || question.marks != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                              : AppColors.textSecondary.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Paper info
                    if (paperName != null) ...[
                      Expanded(
                        child: Text(
                          paperName!,
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                                : AppColors.textSecondary,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],

                    // Marks (if paper name didn't take all space, or simplified)
                    // (Skipping marks in footer if paper name is long, or just showing minimal)
                    if (question.marks != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.star, size: 13, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '${question.marks}m',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                              : AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],

                    // Spacer mostly handled by Expanded above if text is long, but let's be safe
                    if (paperName == null) const Spacer(),

                    // Status badge (if attempted)
                    if (hasAttempt) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 14, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              _getScoreText(latestAttempt!, question.marks),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Chevron
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                  ],
                ),

                // Topic tags
                if (question.topicIds.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  TopicTags(topicIds: question.topicIds),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getScoreText(Map<String, dynamic> attempt, int? marks) {
    final score = attempt['score']; // 0-100 percentage
    final isCorrect = attempt['is_correct'] as bool?;

    if (score != null) {
      return '$score%';
    } else if (isCorrect != null) {
      return isCorrect ? 'Correct' : 'Incorrect';
    }
    return 'Attempted';
  }
}
