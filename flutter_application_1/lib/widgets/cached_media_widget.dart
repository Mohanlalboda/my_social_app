import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

// 🌟 థంబ్‌నైల్స్ ని మెమరీలో సేవ్ చేసుకోవడానికి
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

class _CachedMediaWidgetState extends State<CachedMediaWidget>
    with AutomaticKeepAliveClientMixin {
  CachedVideoPlayerPlus? _player;
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _hasError = false;

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
    super.build(context);

    if (widget.type == 'image') {
      return CachedNetworkImage(
        imageUrl: widget.mediaUrl,
        // 🌟 ఇక్కడ మార్చాం: 'cover' తీసేసి 'contain' పెట్టాం
        fit: widget.isGrid ? BoxFit.cover : BoxFit.contain,
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
      if (widget.isGrid) {
        return Stack(
          fit: StackFit.expand,
          children: [
            _VideoThumbnailLoader(videoUrl: widget.mediaUrl),
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
            Center(
              child: AspectRatio(
                aspectRatio: _player!.controller.value.aspectRatio,
                child: VideoPlayer(_player!.controller),
              ),
            ),
            if (widget.showAudioControl)
              Positioned(
                bottom: 15, // ఇక్కడ పొజిషన్ కొంచెం అడ్జస్ట్ చేశాను
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

// --- Thumbnail Loader ---
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
    if (_globalThumbnailCache.containsKey(widget.videoUrl)) {
      if (mounted) {
        setState(() {
          _thumbData = _globalThumbnailCache[widget.videoUrl];
        });
      }
      return;
    }

    try {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: widget.videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 300,
        quality: 50,
      );

      if (uint8list != null) {
        _globalThumbnailCache[widget.videoUrl] = uint8list;
        if (mounted) {
          setState(() {
            _thumbData = uint8list;
          });
        }
      } else {
        if (mounted) setState(() => _isError = true);
      }
    } catch (e) {
      if (mounted) setState(() => _isError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isError) return Container(color: Colors.grey[900]);
    if (_thumbData != null) {
      return Image.memory(_thumbData!, fit: BoxFit.cover);
    }
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
