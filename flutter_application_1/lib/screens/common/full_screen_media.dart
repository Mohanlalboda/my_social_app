import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart'; // 🌟 అఫీషియల్ ప్యాకేజీ వాడుతున్నాం

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
  late VideoPlayerController _controller; // 🌟 స్టాండర్డ్ కంట్రోలర్
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _controller.play();
          _controller.setLooping(true);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
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
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller), // 🌟 స్టాండర్డ్ వీడియో ప్లేయర్
            )
          : const CircularProgressIndicator(color: Colors.white),
    ),
    floatingActionButton: _isInitialized
        ? FloatingActionButton(
            backgroundColor: Colors.white54,
            onPressed: () => setState(
              () => _controller.value.isPlaying
                  ? _controller.pause()
                  : _controller.play(),
            ),
            child: Icon(
              _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.black,
            ),
          )
        : null,
  );
}
