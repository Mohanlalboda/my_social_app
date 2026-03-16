import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ReelItem extends StatefulWidget {
  final Map<String, dynamic> reelData;
  const ReelItem({super.key, required this.reelData});

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // 🌟 ఫైర్‌బేస్ URL ని ఇక్కడ ప్లేయర్ కి ఇస్తున్నాం
    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.reelData['videoUrl']))
          ..initialize()
              .then((_) {
                setState(() {
                  _isInitialized = true;
                });
                _controller.setLooping(true); // లూప్ లో ప్లే అవ్వడానికి
                _controller.play(); // ఆటోమేటిక్ గా ప్లే అవ్వడానికి
              })
              .catchError((e) {
                debugPrint("🚨 Reel Play Error: $e");
              });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. వీడియో ప్లేయర్
        _isInitialized
            ? GestureDetector(
                onTap: () {
                  // స్క్రీన్ మీద నొక్కితే పాజ్/ప్లే అవ్వడానికి
                  setState(() {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                  });
                },
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              )
            : const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

        // 2. క్యాప్షన్ మరియు యూజర్ పేరు (డిజైన్)
        Positioned(
          bottom: 20,
          left: 15,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "@${widget.reelData['username'] ?? 'User'}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.7,
                child: Text(
                  widget.reelData['caption'] ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
