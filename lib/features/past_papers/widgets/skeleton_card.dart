import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Skeleton loading card with shimmer animation effect
class SkeletonCard extends StatefulWidget {
  final double height;
  final double? width;

  const SkeletonCard({
    super.key,
    this.height = 100,
    this.width,
  });

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment(-1 + _animation.value, 0),
              end: Alignment(_animation.value, 0),
              colors: [
                AppTheme.surfaceDark,
                AppTheme.surfaceDark.withValues(alpha: 0.5),
                AppTheme.surfaceDark,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row skeleton
            Row(
              children: [
                _buildShimmerBox(60, 28),
                const SizedBox(width: 8),
                _buildShimmerBox(80, 28),
                const Spacer(),
                _buildShimmerBox(40, 28),
              ],
            ),
            const SizedBox(height: 12),
            // Content lines skeleton
            _buildShimmerBox(double.infinity, 14),
            const SizedBox(height: 8),
            _buildShimmerBox(200, 14),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerBox(double width, double height) {
    return Container(
      width: width == double.infinity ? null : width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

/// A list of skeleton cards for loading state
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const SkeletonList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 100,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return SkeletonCard(height: itemHeight);
      },
    );
  }
}
