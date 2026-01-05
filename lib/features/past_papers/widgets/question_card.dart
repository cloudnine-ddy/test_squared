import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/question_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import 'topic_tags.dart';
import '../../progress/utils/question_status_helper.dart';

/// Tappable question card that navigates to detail page
class QuestionCard extends StatelessWidget {
  final QuestionModel question;
  final Map<String, dynamic>? latestAttempt;
  final VoidCallback? onReturn; // Callback when returning from detail screen

  const QuestionCard({
    super.key,
    required this.question,
    this.latestAttempt,
    this.onReturn,
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasAttempt ? statusColor.withValues(alpha: 0.5) : AppColors.border.withValues(alpha: 0.5),
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
            // Navigate to question detail and refresh on return
            await context.push('/question/${question.id}');
            // Trigger refresh when coming back
            onReturn?.call();
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
                    // Question text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            question.content,
                            style: TextStyle(
                              color: AppColors.textPrimary,
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

                // Metadata footer - Subtle, condensed
                Row(
                  children: [
                    // Type indicator
                    Icon(
                      question.isMCQ ? Icons.radio_button_checked : Icons.edit,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      question.isMCQ ? 'MCQ' : 'Written',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    // Divider dot
                    if (question.hasPaperInfo || question.marks != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Paper info
                    if (question.hasPaperInfo) ...[
                      Text(
                        question.paperLabel,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],

                    // Divider dot
                    if (question.hasPaperInfo && question.marks != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Marks
                    if (question.marks != null) ...[
                      Icon(Icons.star, size: 13, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '${question.marks} ${question.marks == 1 ? 'mark' : 'marks'}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],

                    const Spacer(),

                    // Status badge (if attempted)
                    if (hasAttempt) ...[
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
                              _getScoreText(),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Right side indicators
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (question.hasFigure)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.image,
                              size: 16,
                              color: Colors.green.withValues(alpha: 0.7),
                            ),
                          ),
                        if (question.hasAiSolution)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: Colors.amber.withValues(alpha: 0.8),
                            ),
                          ),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ],
                ),

                // Topic tags (if present)
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

  /// Get score text for display
  String _getScoreText() {
    if (latestAttempt == null) return '';
    
    final score = latestAttempt!['score'] as int?; // This is 0-100 percentage
    final isCorrect = latestAttempt!['is_correct'] as bool?;
    
    if (score != null) {
      // Score is stored as percentage (0-100)
      if (question.marks != null) {
        // Calculate actual points from percentage
        final actualScore = (score / 100 * question.marks!).toStringAsFixed(1);
        // Remove trailing .0 if whole number
        final scoreStr = actualScore.endsWith('.0') 
            ? actualScore.substring(0, actualScore.length - 2)
            : actualScore;
        return '$scoreStr/${question.marks} ($score%)';
      } else {
        // No marks info, just show percentage
        return '$score%';
      }
    } else if (isCorrect != null) {
      return isCorrect ? 'Correct' : 'Incorrect';
    }
    
    return 'Attempted';
  }
}
