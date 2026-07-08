import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class CircleVideoPlayer extends StatefulWidget {
  final String url;
  const CircleVideoPlayer({super.key, required this.url});

  @override
  State<CircleVideoPlayer> createState() => _CircleVideoPlayerState();
}

class _CircleVideoPlayerState extends State<CircleVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _controller.setLooping(true);
          _controller.play();
          _controller.setVolume(1.0); // Теперь звук включен по умолчанию
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        width: 300,
        height: 300,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black12),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _controller.value.isPlaying ? _controller.pause() : _controller.play();
        });
      },
      onDoubleTap: () {
        setState(() {
          _isMuted = !_isMuted;
          _controller.setVolume(_isMuted ? 0 : 1.0);
        });
      },
      child: Container(
        width: 300,
        height: 300,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
        child: ClipOval(
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),
              if (!_controller.value.isPlaying)
                const Icon(Icons.play_arrow, color: Colors.white, size: 40),
              Positioned(
                bottom: 10,
                right: 10,
                child: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
