import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart'; // 🌟 కొత్త ప్యాకేజీ

// 🌟 థంబ్‌నైల్స్ ని మెమరీలో సేవ్ చేసుకోవడానికి (గ్రిడ్ స్క్రోల్ ఫాస్ట్ గా ఉండటానికి)
final Map<String, Uint8List> _globalThumbnailCache = {};

class CachedMediaWidget extends StatefulWidget {
  final String mediaUrl;
  final String type;
  final bool showAudioControl;
  final bool isGrid;

  const CachedMediaWidget({
    super.key,
    required this.mediaUrl,
    required this.type,
    this.showAudioControl = false,
    this.isGrid = false,
  });

  @override
  State<CachedMediaWidget> createState() => _CachedMediaWidgetState();
}

// 🌟 AutomaticKeepAliveClientMixin యాడ్ చేశాం (స్క్రోల్ చేస్తున్నప్పుడు మళ్ళీ లోడ్ కాకుండా ఉండటానికి)
class _CachedMediaWidgetState extends State<CachedMediaWidget>
    with AutomaticKeepAliveClientMixin {
  CachedVideoPlayerPlus? _player;
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _hasError = false;

  // 🌟 మ్యాజిక్: ఇది true ఉంటేనే స్క్రోల్ చేసినప్పుడు విడ్జెట్ బతికి ఉంటుంది
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (!widget.isGrid) {
      _initializeMedia();
    }
  }

  @override
  void didUpdateWidget(CachedMediaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaUrl != widget.mediaUrl ||
        oldWidget.type != widget.type) {
      _disposePlayer();
      if (!widget.isGrid) {
        _initializeMedia();
      }
    }
  }

  void _initializeMedia() {
    _isMuted = !widget.showAudioControl;
    _isInitialized = false;
    _hasError = false;

    if (widget.type == 'video' && widget.mediaUrl.isNotEmpty) {
      _player = CachedVideoPlayerPlus.networkUrl(Uri.parse(widget.mediaUrl));

      _player!
          .initialize()
          .then((_) {
            if (mounted) {
              setState(() {
                _isInitialized = true;
                _hasError = false;
              });
              _player!.controller.play();
              _player!.controller.setVolume(_isMuted ? 0.0 : 1.0);
              _player!.controller.setLooping(true);
            }
          })
          .catchError((e) {
            debugPrint("Video Player Init Error: $e");
            if (mounted) {
              setState(() {
                _hasError = true;
                _isInitialized = false;
              });
            }
          });
    } else {
      _player = null;
    }
  }

  void _disposePlayer() {
    if (_player != null) {
      _player!.dispose();
      _player = null;
    }
    _isInitialized = false;
  }

  void _toggleMute() {
    if (!_isInitialized || _player == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _player!.controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 🌟 Mixin వాడినప్పుడు ఇది కచ్చితంగా ఉండాలి

    if (widget.type == 'image') {
      return CachedNetworkImage(
        imageUrl: widget.mediaUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (context, url) => Container(
          color: Colors.grey[900],
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.blue,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[900],
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.red, size: 40),
          ),
        ),
      );
    } else if (widget.type == 'video') {
      // 🌟 గ్రిడ్ లో ఉన్నప్పుడు వీడియోకి బదులు 'ఫస్ట్ ఫ్రేమ్ ఫోటో' చూపిస్తాం
      if (widget.isGrid) {
        return Stack(
          fit: StackFit.expand,
          children: [
            _VideoThumbnailLoader(videoUrl: widget.mediaUrl), // 🔥 ఫస్ట్ ఫ్రేమ్
            const Center(
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white70,
                size: 40,
              ),
            ),
          ],
        );
      }

      if (_hasError) {
        return Container(
          color: Colors.black,
          child: const Center(
            child: Icon(Icons.error_outline, color: Colors.red, size: 40),
          ),
        );
      }

      if (_isInitialized &&
          _player != null &&
          _player!.controller.value.isInitialized) {
        return Stack(
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
        );
      } else {
        return Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.blue,
            ),
          ),
        );
      }
    } else {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: Text("Invalid Media", style: TextStyle(color: Colors.white)),
        ),
      );
    }
  }
}

// -----------------------------------------------------------------
// 🌟 వీడియో నుండి ఫస్ట్ ఫ్రేమ్ ఫోటో (Thumbnail) ని తీసే మ్యాజిక్ విడ్జెట్
// -----------------------------------------------------------------
class _VideoThumbnailLoader extends StatefulWidget {
  final String videoUrl;
  const _VideoThumbnailLoader({required this.videoUrl});

  @override
  State<_VideoThumbnailLoader> createState() => _VideoThumbnailLoaderState();
}

class _VideoThumbnailLoaderState extends State<_VideoThumbnailLoader> {
  Uint8List? _thumbData;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    // మెమరీలో ఆల్రెడీ ఉంటే వెంటనే లాగేస్తాం (స్పీడ్ గా ఉంటుంది)
    if (_globalThumbnailCache.containsKey(widget.videoUrl)) {
      if (mounted) {
        setState(() {
          _thumbData = _globalThumbnailCache[widget.videoUrl];
        });
      }
      return;
    }

    try {
      // లేకపోతే వీడియో నుండి ఫోటో జనరేట్ చేస్తాం
      final uint8list = await VideoThumbnail.thumbnailData(
        video: widget.videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 300, // గ్రిడ్ కోసం 300px సైజు చాలు
        quality: 50,
      );

      if (uint8list != null) {
        _globalThumbnailCache[widget.videoUrl] =
            uint8list; // మెమరీలో దాచుకుంటాం
        if (mounted) {
          setState(() {
            _thumbData = uint8list;
          });
        }
      } else {
        if (mounted) setState(() => _isError = true);
      }
    } catch (e) {
      debugPrint("Thumbnail generation error: $e");
      if (mounted) setState(() => _isError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isError) {
      return Container(
        color: Colors.grey[900],
      ); // ఎర్రర్ వస్తే బ్లాక్ బ్యాక్‌గ్రౌండ్
    }
    if (_thumbData != null) {
      return Image.memory(_thumbData!, fit: BoxFit.cover);
    }
    // లోడ్ అయ్యే వరకు చిన్న స్పిన్నర్
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
        ),
      ),
    );
  }
}
