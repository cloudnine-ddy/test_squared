import 'package:flutter/material.dart';
import 'full_screen_image_view.dart';

/// A flexible space header that displays the question image.
/// Can be expanded/collapsed within a SliverAppBar.
class QuestionImageHeader extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const QuestionImageHeader({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return FlexibleSpaceBar(
      background: Container(
        color: const Color(0xFF0B0E14), // Deep dark background
        padding: const EdgeInsets.fromLTRB(16, 60, 16, 16), // Padding to avoid overlap with back button/status bar
        child: Center(
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FullScreenImageView(
                    imageUrl: imageUrl,
                    heroTag: heroTag,
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E232F), // Lighter surface for image
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white24,
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(8.0), // Inner padding
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Hero(
                  tag: heroTag,
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 2.0, // Mild zoom in header
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            color: Colors.blue,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox(
                          height: 200,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image_rounded, color: Colors.white24, size: 48),
                              SizedBox(height: 8),
                              Text(
                                'Image could not be loaded',
                                style: TextStyle(color: Colors.white24),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
