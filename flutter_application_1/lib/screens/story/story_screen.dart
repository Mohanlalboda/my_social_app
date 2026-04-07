// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/safe_elements.dart';

class StoryScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const StoryScreen({super.key, required this.user});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  late AnimationController _animationController;
  int _currentIndex = 0;

  List<Map<String, dynamic>> _userStories = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this);
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });
    _animationController.addListener(() {
      setState(() {});
    });
    _fetchStories();
  }

  Future<void> _fetchStories() async {
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('stories')
          .where('uid', isEqualTo: widget.user['id'] ?? widget.user['uid'])
          .orderBy('timestamp')
          .get();

      if (snapshot.docs.isNotEmpty) {
        _userStories = snapshot.docs.map((doc) {
          var data = doc.data();
          data['storyId'] = doc.id;
          return data;
        }).toList();
        _loadStory();
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      Navigator.pop(context);
    }
  }

  void _loadStory() {
    if (_videoController != null) {
      _videoController!.pause();
      _videoController!.dispose();
      _videoController = null;
    }

    _animationController.stop();
    _animationController.reset();

    var story = _userStories[_currentIndex];
    bool isVideo = story['type'] == 'video';

    if (isVideo) {
      _videoController =
          VideoPlayerController.networkUrl(Uri.parse(story['storyUrl']))
            ..initialize().then((_) {
              if (mounted) {
                setState(() {});
                if (_videoController!.value.isInitialized) {
                  _animationController.duration =
                      _videoController!.value.duration;
                  _videoController!.play();
                  _animationController.forward();
                }
              }
            });
    } else {
      _animationController.duration = const Duration(seconds: 5);
      _animationController.forward();
    }
  }

  void _nextStory() {
    if (_currentIndex < _userStories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _loadStory();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _loadStory();
    } else {
      _loadStory();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_userStories.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    var story = _userStories[_currentIndex];
    bool isVideo = story['type'] == 'video';

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final double screenWidth = MediaQuery.of(context).size.width;
          final double dx = details.globalPosition.dx;
          if (dx < screenWidth / 3) {
            _previousStory();
          } else {
            _nextStory();
          }
        },
        onLongPress: () {
          _animationController.stop();
          if (isVideo) _videoController?.pause();
        },
        onLongPressUp: () {
          _animationController.forward();
          if (isVideo) _videoController?.play();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isVideo)
              _videoController != null && _videoController!.value.isInitialized
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoController!.value.size.width,
                        height: _videoController!.value.size.height,
                        child: VideoPlayer(_videoController!),
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
            else
              CachedNetworkImage(
                imageUrl: story['storyUrl'],
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white),
                ),
              ),

            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 10,
              right: 10,
              child: Row(
                children: _userStories.asMap().entries.map((entry) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: LinearProgressIndicator(
                        value: entry.key < _currentIndex
                            ? 1.0
                            : (entry.key == _currentIndex
                                  ? _animationController.value
                                  : 0.0),
                        backgroundColor: Colors.grey.withValues(alpha: 0.5),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                        minHeight: 2,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            Positioned(
              top: MediaQuery.of(context).padding.top + 25,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  SafeProfilePic(
                    base64String: story['profilePic'],
                    radius: 18,
                    fallbackText: (story['username'] ?? "U")[0],
                  ),
                  const SizedBox(width: 10),
                  Text(
                    story['username'] ?? "User",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                      shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
