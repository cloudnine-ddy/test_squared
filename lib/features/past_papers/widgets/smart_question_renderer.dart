import 'package:flutter/material.dart';
import '../models/question_blocks.dart';
import '../../../core/theme/app_colors.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/wired/wired_widgets.dart';
import 'pdf_crop_viewer.dart';

/// Smart Renderer that implements the "Sticky Figures" design
/// Splits content into a fixed top panel (figures) and a scrollable list (questions)
class SmartQuestionRenderer extends StatefulWidget {
  final List<ExamContentBlock> blocks;
  final Function(Map<String, String>) onAnswersChanged;
  final bool showSolutions;
  final List<dynamic>? perPartFeedback;
  final Map<String, dynamic>? savedAnswers;
  final bool isSubmitted;
  final VoidCallback? onFigureTap;
  final bool isPremium;
  final VoidCallback? onUpgrade;

  const SmartQuestionRenderer({
    super.key,
    required this.blocks,
    required this.onAnswersChanged,
    this.showSolutions = false,
    this.perPartFeedback,
    this.savedAnswers,
    this.isSubmitted = false,
    this.onFigureTap,
    this.isPremium = true,
    this.onUpgrade,
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
  final Set<int> _expandedIndices = {0}; // Default first one expanded

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
        padding: const EdgeInsets.only(bottom: 20, left: 16, right: 16, top: 16),
        itemCount: _questionParts.length,
        separatorBuilder: (ctx, i) => const SizedBox(height: 24),
        itemBuilder: (context, index) {
          return _buildQuestionCard(_questionParts[index], index);
        },
      );
  }

  Widget _buildQuestionCard(_ProcessedPart partWrapper, int index) {
    final block = partWrapper.block;
    final contextText = partWrapper.contextText;
    final isExpanded = _expandedIndices.contains(index);

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
    
    // Calculate feedback color based on score: green (>80), orange (>0), red (0)
    final feedbackColor = (score > 80)
        ? Colors.green
        : (score > 0)
            ? Colors.orange
            : Colors.red;

    return WiredCard(
      backgroundColor: Colors.white,
      borderColor: hasFeedback
          ? (isCorrect ? Colors.green : Colors.red)
          : AppColors.primary.withValues(alpha: 0.15),
      borderWidth: hasFeedback ? 2.2 : 1.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Part (a) - [X] marks - CLICKABLE TOGGLE
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                if (_expandedIndices.contains(index)) {
                  _expandedIndices.remove(index);
                } else {
                  _expandedIndices.add(index);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Expand/collapse icon
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                    color: AppColors.primary,
                    size: 26,
                  ),
                  const SizedBox(width: 4),

                  // Part Label Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasFeedback
                          ? (isCorrect ? Colors.green.withValues(alpha: 0.05) : Colors.red.withValues(alpha: 0.05))
                          : AppColors.primary.withValues(alpha: 0.05),
                      border: Border.all(
                        color: hasFeedback
                            ? (isCorrect ? Colors.green : Colors.red)
                            : AppColors.primary.withValues(alpha: 0.2),
                        width: 1.2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Part (${block.label})'.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'PatrickHand',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: hasFeedback
                            ? (isCorrect ? Colors.green.shade800 : Colors.red.shade800)
                            : AppColors.primary,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),
                  
                  // Part content preview (only when collapsed)
                  if (!isExpanded)
                    Expanded(
                      child: Text(
                        block.content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PatrickHand',
                          color: AppColors.primary.withValues(alpha: 0.5),
                          fontSize: 17,
                        ),
                      ),
                    ),
                  
                  if (isExpanded) ...[
                    if (hasFeedback) ...[
                       const SizedBox(width: 8),
                       Icon(
                         isCorrect ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                         size: 20,
                         color: isCorrect ? Colors.green : Colors.red,
                       ),
                    ],
                    const Spacer(),
                  ],
                  
                  // Marks badge - Sketchy yellow bubble
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                      border: Border.all(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.3),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (hasFeedback ? '$score/${block.marks} marks' : '${block.marks} marks').toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'PatrickHand',
                        color: const Color(0xFF232832),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isExpanded) ...[
            const WiredDivider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (contextText != null && contextText.isNotEmpty) ...[
                    Text(
                      contextText,
                      style: TextStyle(
                        fontFamily: 'PatrickHand',
                        fontSize: 18,
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
                      fontFamily: 'PatrickHand',
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Input Field
                  _buildInputArea(block),

                  // AI Feedback Box - Color based on score
                  // Blurred for free users with upgrade prompt
                  if (hasFeedback && feedbackText.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    if (widget.isPremium)
                      WiredCard(
                        backgroundColor: feedbackColor.withValues(alpha: 0.05),
                        borderColor: feedbackColor.withValues(alpha: 0.5),
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          feedbackText,
                          style: TextStyle(
                            fontFamily: 'PatrickHand',
                            fontStyle: FontStyle.italic,
                            color: feedbackColor,
                            fontSize: 17,
                            height: 1.4,
                          ),
                        ),
                      )
                    else
                      _buildBlurredFeedbackWithUpgrade(feedbackText, feedbackColor),
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
        style: TextStyle(
          fontFamily: 'PatrickHand',
          fontSize: 19, 
          height: 1.4,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: widget.isSubmitted ? '' : 'Write your answer here...',
          hintStyle: TextStyle(
            fontFamily: 'PatrickHand',
            color: Colors.grey.shade400,
            fontSize: 16,
          ),
          filled: true,
          fillColor: const Color(0xFFF9F9F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
          ),
          contentPadding: const EdgeInsets.all(16),
        ),
     );
  }

  // Solution section removed - Official Answer and AI Model Answer are in separate tabs
  Widget _buildSolution(QuestionPartBlock block) {
     // Previously showed Official Answer and AI Model Answer here
     // Now removed since these are available in the Official and AI Explanation tabs
     return const SizedBox.shrink();
  }

  /// Builds a blurred feedback section with a premium upgrade overlay for free users
  Widget _buildBlurredFeedbackWithUpgrade(String feedbackText, Color feedbackColor) {
    return Stack(
      children: [
        // Blurred feedback content
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: feedbackColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: feedbackColor.withValues(alpha: 0.5)),
              ),
              child: Text(
                feedbackText,
                style: TextStyle(
                  fontFamily: 'PatrickHand',
                  fontStyle: FontStyle.italic,
                  color: feedbackColor,
                  fontSize: 17,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),

        // Premium unlock overlay - Sketchy hand-drawn style (compact layout)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: AppColors.background.withValues(alpha: 0.6),
            ),
            child: Center(
              child: WiredCard(
                backgroundColor: AppColors.background,
                borderColor: Colors.amber,
                borderWidth: 2.5,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Lock icon with sketchy circle
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: CustomPaint(
                        painter: _SketchyCirclePainter(color: Colors.amber),
                        child: const Center(
                          child: Icon(
                            Icons.lock_outline,
                            size: 16,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Text column
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Hints Locked',
                          style: TextStyle(
                            fontFamily: 'PatrickHand',
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Upgrade to unlock',
                          style: TextStyle(
                            fontFamily: 'PatrickHand',
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    // Upgrade button
                    WiredButton(
                      onPressed: widget.onUpgrade ?? () {},
                      backgroundColor: Colors.amber,
                      filled: true,
                      borderColor: Colors.amber.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Upgrade',
                            style: TextStyle(
                              fontFamily: 'PatrickHand',
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
  final VoidCallback? onFigureTap;

  const CollapsibleFiguresPanel({
    super.key,
    required this.figures,
    this.initiallyExpanded = false,
    this.onFigureTap,
  });

  @override
  State<CollapsibleFiguresPanel> createState() => _CollapsibleFiguresPanelState();
}

class _CollapsibleFiguresPanelState extends State<CollapsibleFiguresPanel> with TickerProviderStateMixin {
  late bool _expanded;
  late TabController _tabController;
  int _activeIndex = 0;
  double _manualHeight = 220.0; // Default expanded height

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _loadPreferences(); // Load user saved state
    
    if (widget.figures.isNotEmpty) {
       _tabController = TabController(length: widget.figures.length, vsync: this);
       _tabController.addListener(() {
         setState(() {
           _activeIndex = _tabController.index;
         });
       });
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _expanded = prefs.getBool('pref_figures_panel_expanded') ?? widget.initiallyExpanded;
        _manualHeight = prefs.getDouble('pref_figures_panel_height') ?? 220.0;
      });
    }
  }

  Future<void> _saveExpanded(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_figures_panel_expanded', value);
  }

  Future<void> _saveHeight(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pref_figures_panel_height', value);
  }

  @override
  void dispose() {
    if (widget.figures.isNotEmpty) _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.figures.isEmpty) return const SizedBox.shrink();
    
    const double kCollapsedHeight = 42.0;
    const double kMinExpandedHeight = 100.0;
    const double kMaxExpandedHeight = 500.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          height: _expanded ? _manualHeight : kCollapsedHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F2E9), // Darker Sketchy Beige for contrast
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Merged Header & Tabs - Use InkWell on the whole row for better UX
          InkWell(
            onTap: () {
              final newState = !_expanded;
              setState(() => _expanded = newState);
              _saveExpanded(newState);
            },
            child: Container(
              height: kCollapsedHeight,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  // Label & Icon (No separate InkWell needed anymore)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.collections_outlined, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'FIGURES (${widget.figures.length})',
                        style: const TextStyle(
                          fontFamily: 'PatrickHand',
                          fontSize: 16,
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                
                // Vertical Divider
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  width: 1.5,
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),

                // Inline Tab Selector (Visible when expanded or always?)
                // Let's make it always visible if multiple figures
                if (widget.figures.length > 1)
                  Expanded(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.figures.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (ctx, i) {
                        final isSelected = i == _activeIndex;
                        final label = widget.figures[i].figureLabel.replaceAll('Figure', 'Fig');
                        return InkWell(
                          onTap: () {
                            if (!_expanded) setState(() => _expanded = true);
                            _tabController.animateTo(i);
                          },
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: isSelected ? Border.all(color: AppColors.primary.withValues(alpha: 0.2)) : null,
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontFamily: 'PatrickHand',
                                  color: isSelected ? AppColors.primary : Colors.grey.shade600,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                if (widget.figures.length <= 1) const Spacer(),

                // Status Text
                if (!_expanded)
                  Text(
                    'SHOW',
                    style: const TextStyle(
                      fontFamily: 'PatrickHand',
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  Text(
                    'HIDE',
                    style: const TextStyle(
                      fontFamily: 'PatrickHand',
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                ),
              ],
            ),
          ),
        ),

          // Content Area (Image)
          if (_expanded) ...[
            const WiredDivider(),
            Expanded(
              child: Container(
                color: Colors.white,
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: widget.figures
                      .map((fig) => _buildFigurePage(fig, _manualHeight - kCollapsedHeight))
                      .toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    ),

    // 2. Resizable Handle (The "百叶窗" Drag Handle)
    if (_expanded)
      GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() {
            _manualHeight += details.delta.dy;
            _manualHeight = _manualHeight.clamp(kMinExpandedHeight, kMaxExpandedHeight);
          });
        },
        onVerticalDragEnd: (_) => _saveHeight(_manualHeight),
        child: Container(
          width: double.infinity,
          height: 20, // Hit area
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

  Widget _buildFigurePage(FigureBlock block, double availableHeight) {
    final hasUrl = block.url != null && block.url!.isNotEmpty;
    final hasPdfInfo = block.meta != null && 
                       block.meta!['pdf_url'] != null && 
                       block.meta!['figure_location'] != null;

    // Estimate available image height: total - caption height - padding
    final imageAreaHeight = (availableHeight - (block.description.isNotEmpty ? 40 : 0) - 24).clamp(80.0, 500.0);

    return GestureDetector(
      onTap: widget.onFigureTap,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(), // Disable internal scrolling for better drag UX
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image/PDF Container - Scale to fill available height
            SizedBox(
              height: imageAreaHeight,
              width: double.infinity,
              child: hasUrl
                  ? Image.network(
                      block.url!,
                      fit: BoxFit.contain, // Maintain aspect ratio while filling height
                      loadingBuilder: (ctx, child, p) =>
                          p == null ? child : const Center(child: CircularProgressIndicator()),
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                    )
                  : hasPdfInfo
                      ? _buildPdfCrop(block)
                      : const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            // Caption
            if (block.figureLabel.isNotEmpty || block.description.isNotEmpty)
              Text(
                '${block.figureLabel}${block.figureLabel.isNotEmpty ? ': ' : ''}${block.description}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'PatrickHand',
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  height: 1.1,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfCrop(FigureBlock block) {
    final pdfUrl = block.meta!['pdf_url'] as String;
    final loc = block.meta!['figure_location'] as Map<String, dynamic>;

    return PdfCropViewer(
      pdfUrl: pdfUrl,
      pageNumber: loc['page'] ?? 1,
      x: (loc['x_percent'] ?? 0).toDouble(),
      y: (loc['y_percent'] ?? 0).toDouble(),
      width: (loc['width_percent'] ?? 100).toDouble(),
      height: (loc['height_percent'] ?? 100).toDouble(),
    );
  }
}

/// Custom painter for a hand-drawn sketchy circle effect
class _SketchyCirclePainter extends CustomPainter {
  final Color color;
  
  _SketchyCirclePainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 2;
    
    // Draw a slightly wobbly circle for hand-drawn effect
    final path = Path();
    final random = math.Random(42); // Fixed seed for consistency
    
    for (int i = 0; i <= 360; i += 10) {
      final angle = i * math.pi / 180;
      final wobble = (random.nextDouble() - 0.5) * 1.5;
      final r = radius + wobble;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
