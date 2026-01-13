import 'package:flutter/material.dart';
import '../models/question_blocks.dart';
import '../../../core/theme/app_colors.dart';

/// Smart Renderer for structured exam content
/// Handles:
/// - Text Blocks
/// - Figure Blocks (with styled "Figure X" captions)
/// - Question Parts (with styled "Part (a)" badges and input fields)
class SmartQuestionRenderer extends StatefulWidget {
  final List<ExamContentBlock> blocks;
  final Function(Map<String, String>) onAnswersChanged;
  final bool showSolutions;
  final List<dynamic>? perPartFeedback;
  final Map<String, dynamic>? savedAnswers; // Pre-fill with saved answers
  final bool isSubmitted; // Lock inputs after submission

  const SmartQuestionRenderer({
    super.key,
    required this.blocks,
    required this.onAnswersChanged,
    this.showSolutions = false,
    this.perPartFeedback,
    this.savedAnswers,
    this.isSubmitted = false,
  });

  @override
  State<SmartQuestionRenderer> createState() => _SmartQuestionRendererState();
}

class _SmartQuestionRendererState extends State<SmartQuestionRenderer> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _answers = {}; // Changed to String for consistency with onAnswersChanged

  @override
  void initState() {
    super.initState();
    print('🎮 Initializing controllers for ${widget.blocks.length} blocks');

    // Initialize controllers for each question part
    for (var block in widget.blocks) {
      if (block is QuestionPartBlock) {
        final label = block.label;
        print('  📝 Creating controller for label: "$label"');

        // Pre-fill with saved answer if available
        final savedAnswer = widget.savedAnswers?[label]?.toString() ?? '';
        _controllers[label] = TextEditingController(text: savedAnswer);
        _answers[label] = savedAnswer;

        if (savedAnswer.isNotEmpty) {
          print('  ✅ Pre-filled "$label" with saved answer');
        }

        _controllers[label]!.addListener(() {
          setState(() {
            _answers[label] = _controllers[label]!.text;
          });
          widget.onAnswersChanged(_answers);
        });
      }
    }

    print('🎮 Total controllers created: ${_controllers.length}');
    print('🎮 Controller keys: ${_controllers.keys.toList()}');
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(SmartQuestionRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.perPartFeedback != oldWidget.perPartFeedback) {
      print('🔔 perPartFeedback updated!');
      print('   New feedback: ${widget.perPartFeedback}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.blocks.map((block) => _buildBlock(block)).toList(),
    );
  }

  Widget _buildBlock(ExamContentBlock block) {
    if (block is TextBlock) {
      return _buildTextBlock(block);
    } else if (block is FigureBlock) {
      return _buildFigureBlock(block);
    } else if (block is QuestionPartBlock) {
      return _buildQuestionPartBlock(block);
    }
    return const SizedBox.shrink();
  }

  Widget _buildTextBlock(TextBlock block) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        block.content,
        style: const TextStyle(
          fontSize: 16,
          height: 1.5,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildFigureBlock(FigureBlock block) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 350),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.textSecondary.withValues(alpha: 0.1),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: block.url != null
                  ? Image.network(
                      block.url!,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, stack) => _buildImagePlaceholder(),
                    )
                  : _buildImagePlaceholder(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            block.figureLabel,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          if (block.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              block.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 200,
      alignment: Alignment.center,
      color: Colors.grey.withValues(alpha: 0.1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_not_supported,
            size: 48,
            color: AppColors.textSecondary.withValues(alpha: 0.3)
          ),
          const SizedBox(height: 8),
          Text(
            'Image not available',
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQuestionPartBlock(QuestionPartBlock block) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge for Part (a)
              Container(
                margin: const EdgeInsets.only(right: 12, top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  block.label.replaceAll(RegExp(r'[()]'), ''), // Clean (a) -> a
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  block.content,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // Marks badge
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '[${block.marks}]',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInputArea(block),

          if (widget.showSolutions) ...[
            const SizedBox(height: 16),
            _buildSolution(block),
          ],
        ],
      ),
    );
  }

  Widget _buildSolution(QuestionPartBlock block) {
    if (block.officialAnswer == null && block.aiAnswer == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Solution', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF166534))),
          const SizedBox(height: 8),
          if (block.officialAnswer != null && block.officialAnswer!.isNotEmpty) ...[
             const Text('Official Answer:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
             Text(block.officialAnswer!, style: const TextStyle(color: Color(0xFF14532D))),
             const SizedBox(height: 12),
          ],
          if (block.aiAnswer != null && block.aiAnswer!.isNotEmpty) ...[
             const Text('AI Explanation:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
             Text(block.aiAnswer!, style: const TextStyle(color: Color(0xFF14532D), fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea(QuestionPartBlock block) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controllers[block.label],
          maxLines: 4,
          enabled: !widget.showSolutions && !widget.isSubmitted, // Lock after submission
          decoration: InputDecoration(
            hintText: widget.isSubmitted ? 'Answer submitted' : 'Write your answer here...',
            filled: true,
            fillColor: (widget.showSolutions || widget.isSubmitted) ? Colors.grey.shade100 : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),

        // Display AI feedback for this part if available
        if (widget.perPartFeedback != null) ...[
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              print('🔍 Checking feedback for part: ${block.label}');
              print('   Available feedback: ${widget.perPartFeedback}');

              // Find feedback for this specific part
              final feedbackList = widget.perPartFeedback as List;
              final feedback = feedbackList.cast<Map<String, dynamic>>().firstWhere(
                (f) {
                  print('   Comparing "${f['label']}" with "${block.label}"');
                  return f['label'] == block.label;
                },
                orElse: () => <String, dynamic>{},
              );

              print('   Found feedback: $feedback');

              if (feedback.isEmpty) {
                print('   ❌ No feedback found for ${block.label}');
                return const SizedBox.shrink();
              }

              final isCorrect = feedback['isCorrect'] ?? false;
              final score = feedback['score'] ?? 0;
              final feedbackText = feedback['feedback'] ?? '';
              final marks = block.marks ?? 0;

              print('   ✅ Rendering feedback: $score/$marks marks');

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  border: Border.all(
                    color: isCorrect ? Colors.green : Colors.red,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCorrect ? Icons.check_circle : Icons.cancel,
                          color: isCorrect ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Score: $score/$marks marks',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isCorrect ? Colors.green.shade700 : Colors.red.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    if (feedbackText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        feedbackText,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildSpecificInput(QuestionPartBlock block, TextEditingController controller) {
    switch (block.inputType) {
      case 'text_area':
        return TextField(
          controller: controller,
          maxLines: 6,
          readOnly: widget.showSolutions, // Make read-only when showing solutions
          decoration: const InputDecoration(
            hintText: 'Write your answer here...',
            contentPadding: EdgeInsets.all(16),
            border: InputBorder.none,
          ),
        );
      case 'fill_in_blanks':
        return TextField(
          controller: controller,
          readOnly: widget.showSolutions,
          decoration: const InputDecoration(
            hintText: 'Answer...',
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: InputBorder.none,
          ),
        );
      case 'mcq':
        if (block.options == null) return const Text('No options');
        return Column(
          children: block.options!.map((opt) {
            final isSelected = controller.text == opt;
            final isCorrect = block.correctAnswer == opt;

            Color? bgColor;
            Color? borderColor;

            if (widget.showSolutions) {
               if (isCorrect) {
                 bgColor = Colors.green.withValues(alpha: 0.2);
                 borderColor = Colors.green;
               } else if (isSelected && !isCorrect) {
                 bgColor = Colors.red.withValues(alpha: 0.2);
                 borderColor = Colors.red;
               }
            } else if (isSelected) {
               bgColor = AppColors.primary.withValues(alpha: 0.1);
            }

            return InkWell(
              onTap: widget.showSolutions ? null : () {
                controller.text = opt;
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border(
                    bottom: BorderSide(
                      color: borderColor ?? AppColors.textSecondary.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        opt,
                        style: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      default:
        return TextField(
          controller: controller,
          maxLines: 3,
          readOnly: widget.showSolutions,
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.all(16),
          ),
        );
    }
  }
}
