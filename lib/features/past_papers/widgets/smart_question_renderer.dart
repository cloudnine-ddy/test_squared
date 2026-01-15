import 'package:flutter/material.dart';
import '../models/question_blocks.dart';
import '../../../core/theme/app_colors.dart';
import 'dart:math' as math;

/// Smart Renderer that implements the "Sticky Figures" design
/// Splits content into a fixed top panel (figures) and a scrollable list (questions)
class SmartQuestionRenderer extends StatefulWidget {
  final List<ExamContentBlock> blocks;
  final Function(Map<String, String>) onAnswersChanged;
  final bool showSolutions;
  final List<dynamic>? perPartFeedback;
  final Map<String, dynamic>? savedAnswers;
  final bool isSubmitted;

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

class _SmartQuestionRendererState extends State<SmartQuestionRenderer> with TickerProviderStateMixin {
  // State for inputs
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _answers = {};

  // State for block processing
  late List<_ProcessedPart> _questionParts;

  @override
  void initState() {
    super.initState();
    _processBlocks();

    // Initialize controllers
    for (var part in _questionParts) {
      final label = part.block.label;
      final savedAnswer = widget.savedAnswers?[label]?.toString() ?? '';
      _controllers[label] = TextEditingController(text: savedAnswer);
      _answers[label] = savedAnswer;

      _controllers[label]!.addListener(() {
        setState(() {
          _answers[label] = _controllers[label]!.text;
        });
        widget.onAnswersChanged(_answers);
      });
    }
  }

  @override
  void dispose() {
    for (var c in _controllers.values) c.dispose();
    super.dispose();
  }

  /// Separates figures from questions and merges context text
  void _processBlocks() {
    _questionParts = [];

    // Use index-based iteration for lookahead
    for (int i = 0; i < widget.blocks.length; i++) {
      final block = widget.blocks[i];

      if (block is FigureBlock) {
        // Figures are handled globally by QuestionDetailScreen now, so we skip/ignore them here
        // to prevent double rendering.
        continue;
      }

      if (block is TextBlock) {
        // Lookahead merging logic
        if (i + 1 < widget.blocks.length) {
          final nextBlock = widget.blocks[i + 1];
          if (nextBlock is QuestionPartBlock) {
            _questionParts.add(_ProcessedPart(
              block: nextBlock,
              contextText: block.content,
            ));
            i++;
            continue;
          }
        }
        continue;
      }

      if (block is QuestionPartBlock) {
        _questionParts.add(_ProcessedPart(
          block: block,
          contextText: null,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
      // Just render the list of questions. Figures are handled by parent.
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 20, left: 16, right: 16, top: 0),
        itemCount: _questionParts.length,
        separatorBuilder: (ctx, i) => const SizedBox(height: 24),
        itemBuilder: (context, index) {
          return _buildQuestionCard(_questionParts[index]);
        },
      );
  }

  Widget _buildQuestionCard(_ProcessedPart partWrapper) {
    final block = partWrapper.block;
    final contextText = partWrapper.contextText;

    // Find feedback for this specific part if available
    Map<String, dynamic>? partFeedback;
    if (widget.perPartFeedback != null) {
      try {
        partFeedback = widget.perPartFeedback!.firstWhere(
          (f) => f['label'] == block.label,
          orElse: () => null,
        );
      } catch (e) {
        // ignore
      }
    }

    final isCorrect = partFeedback?['isCorrect'] ?? false;
    final score = partFeedback?['score'] ?? 0;
    final feedbackText = partFeedback?['feedback'] ?? '';
    final hasFeedback = partFeedback != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasFeedback
              ? (isCorrect ? Colors.green : Colors.red)
              : AppColors.textSecondary.withValues(alpha: 0.1),
          width: hasFeedback ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            offset: const Offset(0, 2),
            blurRadius: 4,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Part (a) - [X] marks
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: hasFeedback
                  ? (isCorrect ? Colors.green.withValues(alpha: 0.05) : Colors.red.withValues(alpha: 0.05))
                  : null,
              border: Border(bottom: BorderSide(
                color: hasFeedback
                  ? (isCorrect ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2))
                  : Colors.grey.shade100
              )),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Text(
                  'Part (${block.label})',
                  style: TextStyle(
                    fontFamily: 'PatrickHand',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: hasFeedback
                        ? (isCorrect ? Colors.green.shade700 : Colors.red.shade700)
                        : AppColors.primary,
                  ),
                ),
                if (hasFeedback) ...[
                   const SizedBox(width: 8),
                   Icon(
                     isCorrect ? Icons.check_circle : Icons.cancel,
                     size: 18,
                     color: isCorrect ? Colors.green : Colors.red,
                   ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    hasFeedback ? '$score/${block.marks} marks' : '${block.marks} marks',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: hasFeedback
                          ? (isCorrect ? Colors.green.shade800 : Colors.red.shade800)
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Context Text (if any)
                if (contextText != null && contextText.isNotEmpty) ...[
                  Text(
                    contextText,
                    style: TextStyle(
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                      color: AppColors.textPrimary.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Actual Question Content
                Text(
                  block.content,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Input Field
                _buildInputArea(block),

                // AI Feedback Box
                if (hasFeedback && feedbackText.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCorrect ? Colors.green.withValues(alpha: 0.05) : Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      // border: Border.all(color: isCorrect ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      feedbackText,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: isCorrect ? Colors.green.shade900 : Colors.red.shade900,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],

                 // Solution View
                if (widget.showSolutions) ...[
                  const SizedBox(height: 20),
                  _buildSolution(block),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Reuse existing/simplified input builder logic
  Widget _buildInputArea(QuestionPartBlock block) {
     final controller = _controllers[block.label];
     if (controller == null) return SizedBox.shrink();

     // Determine input type helper
     // For now default to text area similar to original but cleaned up
     return TextField(
        controller: controller,
        maxLines: 6,
        enabled: !widget.showSolutions && !widget.isSubmitted,
        style: const TextStyle(fontSize: 16, height: 1.4),
        decoration: InputDecoration(
          hintText: widget.isSubmitted ? '' : 'Write your answer here...',
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
     );
  }

  Widget _buildSolution(QuestionPartBlock block) {
     final hasOfficial = block.officialAnswer != null && block.officialAnswer!.isNotEmpty;
     final hasAi = block.aiAnswer != null && block.aiAnswer!.isNotEmpty;

     if (!hasOfficial && !hasAi) {
       return const SizedBox.shrink();
     }

     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         // Official Answer (Mark Scheme)
         if (hasOfficial)
           Container(
             width: double.infinity,
             margin: const EdgeInsets.only(bottom: 12),
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
               color: Colors.green.withValues(alpha: 0.05),
               borderRadius: BorderRadius.circular(8),
               border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
             ),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 6),
                      Text('Official Answer', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(block.officialAnswer!, style: TextStyle(color: Colors.green.shade900, height: 1.4)),
               ],
             ),
           ),

         // AI Model Answer
         if (hasAi)
           Container(
             width: double.infinity,
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
               color: Colors.blue.withValues(alpha: 0.05),
               borderRadius: BorderRadius.circular(8),
               border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
             ),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 6),
                      Text('AI Model Answer', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(block.aiAnswer!, style: TextStyle(color: Colors.blue.shade900, height: 1.4)),
               ],
             ),
           ),
       ],
     );
  }
}

class _ProcessedPart {
  final QuestionPartBlock block;
  final String? contextText;
  _ProcessedPart({required this.block, this.contextText});
}

class CollapsibleFiguresPanel extends StatefulWidget {
  final List<FigureBlock> figures;
  final bool initiallyExpanded;

  const CollapsibleFiguresPanel({
    super.key,
    required this.figures,
    this.initiallyExpanded = false,
  });

  @override
  State<CollapsibleFiguresPanel> createState() => _CollapsibleFiguresPanelState();
}

class _CollapsibleFiguresPanelState extends State<CollapsibleFiguresPanel> with TickerProviderStateMixin {
  late bool _expanded;
  late TabController _tabController;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    if (widget.figures.isNotEmpty) {
       _tabController = TabController(length: widget.figures.length, vsync: this);
       _tabController.addListener(() {
         setState(() {
           _activeIndex = _tabController.index;
         });
       });
    }
  }

  @override
  void dispose() {
    if (widget.figures.isNotEmpty) _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.figures.isEmpty) return const SizedBox.shrink();

    const double kCollapsedHeight = 50.0;
    const double kMaxExpandedHeight = 300.0; // Fixed max height as requested

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      height: _expanded ? kMaxExpandedHeight : kCollapsedHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        border: Border(
          bottom: BorderSide(color: AppColors.primary.withValues(alpha: 0.1), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.image_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Figures (${widget.figures.length})',
                    style: const TextStyle(
                      fontFamily: 'PatrickHand',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _expanded ? 'Hide' : 'Show',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // Content
          if (_expanded)
            Expanded(
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    // Tabs
                    if (widget.figures.length > 1)
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200))
                        ),
                        child: ListView.separated(
                           padding: const EdgeInsets.symmetric(horizontal: 16),
                           scrollDirection: Axis.horizontal,
                           itemCount: widget.figures.length,
                           separatorBuilder: (_,__) => const SizedBox(width: 16),
                           itemBuilder: (ctx, i) {
                             final isSelected = i == _activeIndex;
                             final label = widget.figures[i].figureLabel.replaceAll('Figure', 'Fig');
                             return InkWell(
                               onTap: () => _tabController.animateTo(i),
                               child: Center(
                                 child: Container(
                                   padding: const EdgeInsets.symmetric(vertical: 4),
                                    decoration: BoxDecoration(
                                      border: isSelected ? const Border(bottom: BorderSide(color: AppColors.primary, width: 2)) : null
                                    ),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: isSelected ? AppColors.primary : Colors.grey,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                    ),
                                 ),
                               ),
                             );
                           },
                        ),
                      ),

                    // Image + Caption Scrollable Area
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: widget.figures.map((fig) => _buildFigurePage(fig)).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFigurePage(FigureBlock block) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Container
          SizedBox(
             height: 300,
             child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: block.url != null
                  ? Image.network(
                      block.url!,
                      fit: BoxFit.contain,
                      loadingBuilder: (ctx, child, p) => p == null ? child : const Center(child: CircularProgressIndicator()),
                      errorBuilder: (_,__,___) => const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                    )
                  : const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
             ),
          ),
          const SizedBox(height: 12),
          // Caption
          Text(
            '${block.figureLabel}: ${block.description}',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.4,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
