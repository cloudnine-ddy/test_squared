import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/question_model.dart';
import '../../progress/utils/question_status_helper.dart';
import 'topic_tags.dart';
import '../../../shared/wired/wired_widgets.dart';

/// Simplified MCQ Feed Card that matches QuestionCard (Structured) styling and behavior.
/// Navigates to detail screen on tap instead of inline answering.
class MultipleChoiceFeedCard extends StatelessWidget {
  final QuestionModel question;
  final String? paperName;
  final Map<String, dynamic>? latestAttempt;
  final String? topicId; // Added for navigation context initialization
  final VoidCallback? onReturn; // Callback when returning from detail screen
  final Function(String?)? onAnswerChanged; // Kept for compatibility but unused
  final Function(bool)? onCheckResult;    // Kept for compatibility but unused

  const MultipleChoiceFeedCard({
    super.key,
    required this.question,
    this.paperName,
    this.latestAttempt,
    this.topicId,
    this.onReturn,
    this.onAnswerChanged,
    this.onCheckResult,
  });

  // Sketchy Theme Colors
  static const Color _primaryColor = Color(0xFF2D3E50); // Deep Navy

  TextStyle _patrickHand({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'PatrickHand',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? _primaryColor,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get status color and icon from helper
    final statusColor = QuestionStatusHelper.getStatusColor(latestAttempt);
    final statusIcon = QuestionStatusHelper.getStatusIcon(latestAttempt);
    final hasAttempt = latestAttempt != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () async {
          // Navigate to question detail with topic context
          final uri = Uri(
            path: '/question/${question.id}',
            queryParameters: topicId != null ? {'topicId': topicId} : null,
          );
          await context.push(uri.toString());
          // Trigger refresh when coming back
          onReturn?.call();
        },
        child: WiredCard(
          backgroundColor: Colors.white,
          borderColor: hasAttempt ? statusColor.withValues(alpha: 0.8) : _primaryColor.withValues(alpha: 0.3),
          borderWidth: hasAttempt ? 2.0 : 1.5,
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
                    alignment: Alignment.center,
                    child: Text(
                      '${question.questionNumber}',
                      style: _patrickHand(
                        color: _primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Question text (Preview)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question.content,
                          style: _patrickHand(
                            color: _primaryColor,
                            fontSize: 18,
                            height: 1.3,
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
                    size: 16,
                    color: _primaryColor.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'MCQ',
                    style: _patrickHand(
                      color: _primaryColor.withValues(alpha: 0.6),
                      fontSize: 16,
                    ),
                  ),

                  // Divider
                  if (paperName != null || question.marks != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.4),
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
                        style: _patrickHand(
                          color: _primaryColor.withValues(alpha: 0.6),
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],

                  // Marks (if paper name didn't take all space, or simplified)
                  if (question.marks != null) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '${question.marks}m',
                      style: _patrickHand(
                        color: _primaryColor.withValues(alpha: 0.7),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],

                  // Spacer mostly handled by Expanded above if text is long, but let's be safe
                  if (paperName == null) const Spacer(),

                  // Status badge (if attempted)
                  if (hasAttempt) ...[
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: statusColor.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 18, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            _getScoreText(latestAttempt!, question.marks),
                            style: _patrickHand(
                              color: statusColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Chevron
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward,
                    size: 20,
                    color: _primaryColor.withValues(alpha: 0.4),
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
