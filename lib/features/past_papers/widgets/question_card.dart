import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/question_model.dart';
import 'topic_tags.dart';
import '../../progress/utils/question_status_helper.dart';
import '../../../shared/wired/wired_widgets.dart';

/// Tappable question card that navigates to detail page with sketchy style
class QuestionCard extends StatelessWidget {
  final QuestionModel question;
  final Map<String, dynamic>? latestAttempt;
  final String? topicId; // Context for navigation
  final VoidCallback? onReturn; // Callback when returning from detail screen

  const QuestionCard({
    super.key,
    required this.question,
    this.latestAttempt,
    this.topicId,
    this.onReturn,
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
          // Navigate to question detail and refresh on return
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
                  // Question text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question.content,
                          style: _patrickHand(
                            color: _primaryColor,
                            fontSize: 16,
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

              // Metadata footer - Subtle, condensed
              Row(
                children: [
                  // Type indicator
                  Icon(
                    question.isMCQ ? Icons.radio_button_checked : Icons.edit,
                    size: 16,
                    color: _primaryColor.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    question.isMCQ ? 'MCQ' : 'Written',
                    style: _patrickHand(
                      color: _primaryColor.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),

                  // Divider dot
                  if (question.hasPaperInfo || question.marks != null) ...[
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
                  if (question.hasPaperInfo) ...[
                    Text(
                      question.paperLabel,
                      style: _patrickHand(
                        color: _primaryColor.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],

                  // Divider dot
                  if (question.hasPaperInfo && question.marks != null) ...[
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

                  // Marks
                  if (question.marks != null) ...[
                    Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '${question.marks} ${question.marks == 1 ? 'mark' : 'marks'}',
                      style: _patrickHand(
                        color: _primaryColor.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Status badge (if attempted)
                  if (hasAttempt) ...[
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
                          Icon(statusIcon, size: 16, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            _getScoreText(),
                            style: _patrickHand(
                              color: statusColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
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
                            size: 18,
                            color: Colors.green.withValues(alpha: 0.7),
                          ),
                        ),
                      if (question.hasAiSolution)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.auto_awesome,
                            size: 18,
                            color: Colors.amber.withValues(alpha: 0.8),
                          ),
                        ),
                      Icon(
                        Icons.arrow_forward,
                        size: 20,
                        color: _primaryColor.withValues(alpha: 0.4),
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
