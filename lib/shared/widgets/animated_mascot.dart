import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Animated mascot widget that plays a looping video
class AnimatedMascot extends StatefulWidget {
  final double size;
  final BorderRadius? borderRadius;

  const AnimatedMascot({
    super.key,
    this.size = 40,
    this.borderRadius,
  });

  @override
  State<AnimatedMascot> createState() => _AnimatedMascotState();
}

class _AnimatedMascotState extends State<AnimatedMascot> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.asset('lib/core/assets/videos/mascot.mp4')
        ..setLooping(true)
        ..setVolume(0); // Muted by default

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _controller!.play();
      }
    } catch (e) {
      print('Error initializing mascot video: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(8);

    if (!_isInitialized || _controller == null) {
      // Fallback to icon while loading
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: const Color(0xFF2D3E50).withValues(alpha: 0.1),
          borderRadius: borderRadius,
        ),
        child: const Icon(
          Icons.psychology,
          color: Color(0xFF2D3E50),
          size: 20,
        ),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller!.value.size.width,
            height: _controller!.value.size.height,
            child: VideoPlayer(_controller!),
          ),
        ),
      ),
    );
  }
}
