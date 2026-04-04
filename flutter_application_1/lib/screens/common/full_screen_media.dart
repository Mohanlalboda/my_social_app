import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:video_player/video_player.dart';

// --- IMAGE VIEWER ---
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  const FullScreenImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    body: Center(
      child: InteractiveViewer(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          placeholder: (c, u) =>
              const CircularProgressIndicator(color: Colors.white),
        ),
      ),
    ),
  );
}

// --- VIDEO VIEWER ---
class FullScreenVideoViewer extends StatefulWidget {
  final String videoUrl;
  const FullScreenVideoViewer({super.key, required this.videoUrl});

  @override
  State<FullScreenVideoViewer> createState() => _FullScreenVideoViewerState();
}

class _FullScreenVideoViewerState extends State<FullScreenVideoViewer> {
  late CachedVideoPlayerPlus _player;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _player = CachedVideoPlayerPlus.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _player.controller.play();
          _player.controller.setLooping(true);
        }
      });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    body: Center(
      child: _isInitialized
          ? AspectRatio(
              aspectRatio: _player.controller.value.aspectRatio,
              child: VideoPlayer(_player.controller),
            )
          : const CircularProgressIndicator(color: Colors.white),
    ),
    floatingActionButton: _isInitialized
        ? FloatingActionButton(
            backgroundColor: Colors.white.withValues(alpha: 0.5),
            onPressed: () => setState(
              () => _player.controller.value.isPlaying
                  ? _player.controller.pause()
                  : _player.controller.play(),
            ),
            child: Icon(
              _player.controller.value.isPlaying
                  ? Icons.pause
                  : Icons.play_arrow,
              color: Colors.black,
            ),
          )
        : null,
  );
}
