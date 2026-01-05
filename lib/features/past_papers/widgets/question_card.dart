import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/question_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import 'topic_tags.dart';

/// Tappable question card that navigates to detail page
class QuestionCard extends StatelessWidget {
  final QuestionModel question;

  const QuestionCard({
    super.key,
    required this.question,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            context.push('/question/${question.id}');
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
}
