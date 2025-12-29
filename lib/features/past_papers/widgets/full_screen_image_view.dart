import 'package:flutter/material.dart';

/// A full-screen view for checking diagrams in detail.
/// Supports pinch-to-zoom and Hero animations.
class FullScreenImageView extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const FullScreenImageView({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Centered Zoomable Image
          Center(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 5.0,
              child: Hero(
                tag: heroTag,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                ),
              ),
            ),
          ),

          // Close Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black45,
                shape: const CircleBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
