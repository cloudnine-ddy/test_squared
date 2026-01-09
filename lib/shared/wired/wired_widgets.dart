
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/theme/app_colors.dart';

// Custom painter for hand-drawn/sketchy border effect
// Custom painter for hand-drawn/sketchy border effect
class WiredBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int seed;

  WiredBorderPainter({
    required this.color,
    this.strokeWidth = 2.0,
    this.seed = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter;

    final random = math.Random(seed);
    
    // ROUGH.JS Algorithm Adaptation
    // Draw FOUR lines for each side to simulate sketchy messy stroke and cover gaps
    
    // Top
    for(int i=0; i<4; i++) _drawRoughLine(canvas, paint, Offset(0, 0), Offset(size.width, 0), random);
    
    // Right
    for(int i=0; i<4; i++) _drawRoughLine(canvas, paint, Offset(size.width, 0), Offset(size.width, size.height), random);

    // Bottom
    for(int i=0; i<4; i++) _drawRoughLine(canvas, paint, Offset(size.width, size.height), Offset(0, size.height), random);
    
    // Left
    for(int i=0; i<4; i++) _drawRoughLine(canvas, paint, Offset(0, size.height), Offset(0, 0), random);
  }

  void _drawRoughLine(Canvas canvas, Paint paint, Offset start, Offset end, math.Random random) {
    final path = Path();
    
    // Roughness parameters
    const roughness = 0.5; // Reduced from 1.0 for tighter lines
    const bowing = 0.2; // Reduced from 1.0 to prevent "ballooning" on large shapes
    
    // Random offsets
    final double offset = roughness * (random.nextDouble() - 0.5);
    final diff = end - start;
    final length = diff.distance;
    
    // Midpoint displacement (Bowing)
    // We add a random point in the middle but pushed out perpendicular
    final mid = (start + end) / 2;
    final fallbackAngle = math.atan2(diff.dy, diff.dx);
    final normalAngle = fallbackAngle + math.pi / 2;
    
    // Scale bowing by length but CAP it so giant cards don't look weird
    double bowMagnitude = length * 0.002; // Very subtle bowing factor
    if (bowMagnitude > 1.5) bowMagnitude = 1.5; // Cap at 1.5px bowing
    
    final bowOffset = bowing * (random.nextDouble() - 0.5) * bowMagnitude * 50; 
    // Actually simpler:
    // final bowOffset = (random.nextDouble() - 0.5) * math.min(length * 0.01, 5.0); 
    
    // Updated logic:
    final computedBowing = (random.nextDouble() - 0.5) * bowing * length;
    // We clamp the bowing effect to be very subtle
    final clampedBowing = computedBowing.clamp(-3.0, 3.0); 

    // Control point
    final c = mid + Offset(
      math.cos(normalAngle) * clampedBowing,
      math.sin(normalAngle) * clampedBowing
    );

    final s = start + Offset(roughness * (random.nextDouble() - 0.5), roughness * (random.nextDouble() - 0.5));
    final e = end + Offset(roughness * (random.nextDouble() - 0.5), roughness * (random.nextDouble() - 0.5));

    path.moveTo(s.dx, s.dy);
    path.quadraticBezierTo(c.dx, c.dy, e.dx, e.dy);
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom wired card widget
class WiredCard extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  final Color? backgroundColor;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const WiredCard({
    super.key,
    required this.child,
    this.borderColor = AppColors.primary,
    this.backgroundColor,
    this.borderWidth = 2.0,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: WiredBorderPainter(
        color: borderColor,
        strokeWidth: borderWidth,
        seed: hashCode,
      ),
      child: Container(
        width: width,
        height: height,
        color: backgroundColor,
        padding: padding,
        child: child,
      ),
    );
  }
}

// Custom wired button widget
class WiredButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color borderColor;
  final Color? backgroundColor;
  final Color? hoverColor;
  final bool filled;
  final EdgeInsetsGeometry padding;

  const WiredButton({
    super.key,
    required this.child,
    this.onPressed,
    this.borderColor = AppColors.primary,
    this.backgroundColor,
    this.hoverColor,
    this.filled = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
  });

  @override
  State<WiredButton> createState() => _WiredButtonState();
}

class _WiredButtonState extends State<WiredButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    // Default hover color if not provided
    final defaultHoverColor = const Color(0xFFE8E0D0); 
    
    if (widget.filled) {
      bgColor = _isHovered 
          ? (widget.backgroundColor?.withAlpha(220) ?? AppColors.primary.withAlpha(220))
          : (widget.backgroundColor ?? AppColors.primary);
    } else {
      bgColor = _isHovered ? (widget.hoverColor ?? defaultHoverColor) : Colors.transparent;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          child: CustomPaint(
            painter: WiredBorderPainter(
              color: widget.borderColor,
              strokeWidth: 2.0,
              seed: hashCode,
            ),
            child: Container(
              padding: widget.padding,
              color: bgColor,
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

// Custom wired divider
class WiredDivider extends StatelessWidget {
  final Color color;
  final double thickness;

  const WiredDivider({
    super.key, 
    this.color = AppColors.textSecondary,
    this.thickness = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(double.infinity, thickness),
      painter: _WiredLinePainter(color: color, thickness: thickness),
    );
  }
}

class _WiredLinePainter extends CustomPainter {
  final Color color;
  final double thickness;

  _WiredLinePainter({required this.color, required this.thickness});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final random = math.Random(42);
    final path = Path();
    
    path.moveTo(0, size.height / 2);
    
    double x = 0;
    while (x < size.width) {
      x += 5 + random.nextDouble() * 3;
      final y = size.height / 2 + (random.nextDouble() - 0.5) * 2;
      path.lineTo(x.clamp(0, size.width), y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
