import 'package:flutter/material.dart';
import '../models/question_model.dart';

class PaperOverlayWidget extends StatelessWidget {
  final String imageUrl;
  final List<QuestionModel> questions;
  final Function(QuestionModel)? onQuestionSelected;
  final ScrollController? scrollController;

  const PaperOverlayWidget({
    Key? key,
    required this.imageUrl,
    this.questions = const [],
    this.onQuestionSelected,
    this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // We use fitWidth so the image always takes the full available width.
        // This is crucial for consistent scaling calculations.
        return Stack(
          children: [
            // The PDF Page Image
            Image.network(
              imageUrl,
              fit: BoxFit.fitWidth,
              width: constraints.maxWidth,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 300,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Text('Failed to load page image'),
                  ),
                );
              },
            ),

            // Bounding Box Overlays
            ...questions.map((q) => _buildQuestionOverlay(context, q, constraints.maxWidth)).whereType<Widget>(),
          ],
        );
      },
    );
  }

  Widget? _buildQuestionOverlay(BuildContext context, QuestionModel question, double renderedWidth) {
    final bbox = question.boundingBoxMap;
    if (bbox == null) return null;

    try {
      final double x = (bbox['x'] as num).toDouble();
      final double y = (bbox['y'] as num).toDouble();
      final double w = (bbox['width'] as num).toDouble();
      final double h = (bbox['height'] as num).toDouble();
      final double pageWidth = (bbox['page_width'] as num).toDouble();
      final double pageHeight = (bbox['page_height'] as num).toDouble();

      // Calculate Scale Factor
      // Scale is determined by how much the page is shrunk/expanded to fit the screen width
      final double scale = renderedWidth / pageWidth;

      // Coordinate Transformation
      // PDF System: Origin Bottom-Left. Y increases upwards.
      // Screen System: Origin Top-Left. Y increases downwards.
      
      // Calculate 'top' in screen coordinates
      // pdf_y is distance from bottom.
      // So distance from top is: pageHeight - (pdf_y + h)
      // Note: pdf_y is usually the bottom-left corner of the box.
      // So the top of the box in PDF coords is (y + h).
      // The distance from the TOP of the page to the TOP of the box is pageHeight - (y + h).
      
      final double top = (pageHeight - (y + h)) * scale;
      final double left = x * scale;
      final double width = w * scale;
      final double height = h * scale;

      return Positioned(
        top: top,
        left: left,
        width: width,
        height: height,
        child: GestureDetector(
          onTap: () => onQuestionSelected?.call(question),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              border: Border.all(color: Colors.red, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Q${question.questionNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error rendering overlay for Q${question.questionNumber}: $e');
      return null;
    }
  }
}
