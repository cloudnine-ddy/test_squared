
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
    
    // Roughness parameters - INCREASED for more hand-drawn look
    const roughness = 1.5; // Increased for more visible wobble
    const bowing = 0.4; // Increased for more curve
    
    // Random offsets for start/end points
    final diff = end - start;
    final length = diff.distance;
    
    // Midpoint displacement (Bowing)
    final mid = (start + end) / 2;
    final fallbackAngle = math.atan2(diff.dy, diff.dx);
    final normalAngle = fallbackAngle + math.pi / 2;
    
    // Scale bowing by length
    double bowMagnitude = length * 0.005; // More visible bowing
    if (bowMagnitude > 4.0) bowMagnitude = 4.0; // Higher cap
    
    final computedBowing = (random.nextDouble() - 0.5) * bowing * bowMagnitude * 30;
    final clampedBowing = computedBowing.clamp(-5.0, 5.0); 

    // Control point for curve
    final c = mid + Offset(
      math.cos(normalAngle) * clampedBowing,
      math.sin(normalAngle) * clampedBowing
    );

    // Randomize start and end points slightly
    final s = start + Offset(roughness * (random.nextDouble() - 0.5) * 2, roughness * (random.nextDouble() - 0.5) * 2);
    final e = end + Offset(roughness * (random.nextDouble() - 0.5) * 2, roughness * (random.nextDouble() - 0.5) * 2);

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
      painter: WiredDividerPainter(color: color, thickness: thickness),
    );
  }
}

class WiredDividerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final int seed;
  final Axis axis;

  WiredDividerPainter({
    required this.color, 
    required this.thickness,
    this.seed = 42,
    this.axis = Axis.horizontal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final random = math.Random(seed);
    final path = Path();
    
    if (axis == Axis.horizontal) {
      path.moveTo(0, size.height / 2);
      double x = 0;
      while (x < size.width) {
        x += 5 + random.nextDouble() * 3;
        final y = size.height / 2 + (random.nextDouble() - 0.5) * 2;
        path.lineTo(x.clamp(0, size.width), y);
      }
    } else {
      path.moveTo(size.width / 2, 0);
      double y = 0;
      while (y < size.height) {
        y += 5 + random.nextDouble() * 3;
        final x = size.width / 2 + (random.nextDouble() - 0.5) * 2;
        path.lineTo(x, y.clamp(0, size.height));
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
