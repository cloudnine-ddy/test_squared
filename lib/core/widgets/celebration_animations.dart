import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../theme/app_colors.dart';

/// Celebration overlay for correct answers and achievements
class CelebrationOverlay extends StatefulWidget {
  final Widget child;
  final bool showConfetti;
  final VoidCallback? onComplete;

  const CelebrationOverlay({
    super.key,
    required this.child,
    this.showConfetti = false,
    this.onComplete,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void didUpdateWidget(CelebrationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showConfetti && !oldWidget.showConfetti) {
      _confettiController.play();
      Future.delayed(const Duration(seconds: 3), () {
        widget.onComplete?.call();
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        
        // Confetti from top center
        if (widget.showConfetti)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 1.57, // Down (pi/2)
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.3,
              colors: [
                const Color(0xFFFFD700), // Gold
                AppColors.primary,
                AppColors.accent,
                Colors.orange,
                Colors.green,
              ],
              maxBlastForce: 30,
              minBlastForce: 10,
            ),
          ),
      ],
    );
  }
}

/// Animated checkmark for correct answers
class CorrectAnswerAnimation extends StatefulWidget {
  final VoidCallback? onComplete;

  const CorrectAnswerAnimation({
    super.key,
    this.onComplete,
  });

  @override
  State<CorrectAnswerAnimation> createState() => _CorrectAnswerAnimationState();
}

class _CorrectAnswerAnimationState extends State<CorrectAnswerAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Shake animation for incorrect answers
class IncorrectAnswerAnimation extends StatefulWidget {
  final Widget child;
  final bool trigger;

  const IncorrectAnswerAnimation({
    super.key,
    required this.child,
    required this.trigger,
  });

  @override
  State<IncorrectAnswerAnimation> createState() => _IncorrectAnswerAnimationState();
}

class _IncorrectAnswerAnimationState extends State<IncorrectAnswerAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _offsetAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 10.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(IncorrectAnswerAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_offsetAnimation.value, 0),
          child: widget.child,
        );
      },
    );
  }
}

/// Score reveal animation with count-up
class ScoreRevealAnimation extends StatefulWidget {
  final int score;
  final int maxScore;
  final VoidCallback? onComplete;

  const ScoreRevealAnimation({
    super.key,
    required this.score,
    required this.maxScore,
    this.onComplete,
  });

  @override
  State<ScoreRevealAnimation> createState() => _ScoreRevealAnimationState();
}

class _ScoreRevealAnimationState extends State<ScoreRevealAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _scoreAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scoreAnimation = IntTween(begin: 0, end: widget.score)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (widget.score / widget.maxScore * 100).round();
    final isPerfect = widget.score == widget.maxScore;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Score number
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 500),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.8 + (value * 0.2),
                  child: Text(
                    '${_scoreAnimation.value}/${widget.maxScore}',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: isPerfect ? Colors.green : AppColors.primary,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            // Percentage
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 24,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isPerfect) ...[
              const SizedBox(height: 16),
              Text(
                '🎉 Perfect Score!',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
