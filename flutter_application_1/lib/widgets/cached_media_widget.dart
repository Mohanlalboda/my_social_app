import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:video_player/video_player.dart';

class CachedMediaWidget extends StatefulWidget {
  final String mediaUrl;
  final String type;
  final bool showAudioControl;

  const CachedMediaWidget({
    super.key,
    required this.mediaUrl,
    required this.type,
    this.showAudioControl = false,
  });

  @override
  State<CachedMediaWidget> createState() => _CachedMediaWidgetState();
}

class _CachedMediaWidgetState extends State<CachedMediaWidget> {
  CachedVideoPlayerPlus? _player;
  bool _isInitialized = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initializeMedia();
  }

  // 🌟 బగ్ ఫిక్స్ ఇక్కడే: ఒక స్టోరీ నుండి ఇంకో స్టోరీకి మారినప్పుడు ప్లేయర్‌ని రీస్టార్ట్ చేయడం
  @override
  void didUpdateWidget(CachedMediaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaUrl != widget.mediaUrl ||
        oldWidget.type != widget.type) {
      _disposePlayer();
      _initializeMedia();
    }
  }

  void _initializeMedia() {
    _isMuted = !widget.showAudioControl;
    _isInitialized = false;

    if (widget.type == 'video' && widget.mediaUrl.isNotEmpty) {
      _player = CachedVideoPlayerPlus.networkUrl(Uri.parse(widget.mediaUrl));

      _player!
          .initialize()
          .then((_) {
            if (mounted) {
              setState(() {
                _isInitialized = true;
              });
              _player!.controller.play();
              _player!.controller.setVolume(_isMuted ? 0.0 : 1.0);
              _player!.controller.setLooping(true);
            }
          })
          .catchError((e) {
            debugPrint("Video Player Init Error: $e");
          });
    } else {
      _player = null;
    }
  }

  void _disposePlayer() {
    _player?.dispose();
    _player = null;
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _player?.controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.type == 'image') {
      return CachedNetworkImage(
        imageUrl: widget.mediaUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (context, url) => Container(
          color: Colors.grey[900],
          height: 300,
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.blue,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[900],
          height: 300,
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.red, size: 40),
          ),
        ),
      );
    } else if (widget.type == 'video' && _player != null) {
      return _isInitialized
          ? Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: _player!.controller.value.aspectRatio,
                  child: VideoPlayer(_player!.controller),
                ),
                if (widget.showAudioControl)
                  Positioned(
                    top: 130,
                    right: 15,
                    child: GestureDetector(
                      onTap: _toggleMute,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isMuted ? Icons.volume_off : Icons.volume_up,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : Container(
              height: 300,
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.blue,
                ),
              ),
            );
    } else {
      return Container(
        height: 300,
        color: Colors.grey[900],
        child: const Center(
          child: Text("Invalid Media", style: TextStyle(color: Colors.white)),
        ),
      );
    }
  }
}
