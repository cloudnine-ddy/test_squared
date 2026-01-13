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
  final Function(Map<String, dynamic> answers) onAnswersChanged;
  final Map<String, dynamic>? initialAnswers;
  final bool showSolutions;

  const SmartQuestionRenderer({
    super.key,
    required this.blocks,
    required this.onAnswersChanged,
    this.initialAnswers,
    this.showSolutions = false,
  });

  @override
  State<SmartQuestionRenderer> createState() => _SmartQuestionRendererState();
}

class _SmartQuestionRendererState extends State<SmartQuestionRenderer> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _answers = {};

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    for (final block in widget.blocks) {
      if (block is QuestionPartBlock) {
        final controller = TextEditingController(
          text: widget.initialAnswers?[block.label]?.toString() ?? '',
        );
        _controllers[block.label] = controller;
        _answers[block.label] = widget.initialAnswers?[block.label];

        controller.addListener(() {
          setState(() {
            _answers[block.label] = controller.text;
          });
          widget.onAnswersChanged(_answers);
        });
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
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
    final controller = _controllers[block.label];
    if (controller == null) return const SizedBox.shrink();

    // Styled Input Container
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.15),
        ),
      ),
      child: _buildSpecificInput(block, controller),
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
