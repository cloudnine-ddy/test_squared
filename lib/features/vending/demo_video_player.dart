import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// A widget that plays the demo video in a loop with no controls.
/// Designed for the landing page hero section.
class DemoVideoPlayer extends StatefulWidget {
  const DemoVideoPlayer({super.key});

  @override
  State<DemoVideoPlayer> createState() => _DemoVideoPlayerState();
}

class _DemoVideoPlayerState extends State<DemoVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    // For Flutter Web, load video from web folder via network URL
    _controller = VideoPlayerController.networkUrl(
      Uri.parse('demo_general.mp4'),
    );

    try {
      await _controller.initialize();
      _controller.setLooping(true);
      _controller.setVolume(0); // Mute the video
      _controller.play();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      // Fallback to GIF if video fails
      return Image.asset(
        'lib/core/assets/images/demo_general.gif',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        width: double.infinity,
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }
}
