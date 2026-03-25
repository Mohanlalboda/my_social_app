// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/safe_elements.dart';

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
  List<DocumentSnapshot> _userStories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this);
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });
    _loadAllStoriesOfUser();
  }

  void _loadAllStoriesOfUser() async {
    String ownerId = widget.user['ownerId']?.toString() ?? "";
    DateTime yesterday = DateTime.now().subtract(const Duration(hours: 24));

    var snapshot = await FirebaseFirestore.instance
        .collection('stories')
        .where('ownerId', isEqualTo: ownerId)
        .where('timestamp', isGreaterThanOrEqualTo: yesterday)
        .orderBy('timestamp', descending: false)
        .get();

    if (snapshot.docs.isNotEmpty) {
      if (mounted) {
        setState(() {
          _userStories = snapshot.docs;
          _isLoading = false;
        });

        // 🌟 TRICK: ఇక్కడ మనం ఇమేజెస్ ని ముందే లోడ్ చేస్తున్నాం!
        _preloadImages();

        _showStory();
      }
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  // 🌟 బ్యాక్‌గ్రౌండ్ లో ఫోటోలు ఫాస్ట్ గా డౌన్‌లోడ్ చేసి పెట్టుకునే ఫంక్షన్
  void _preloadImages() {
    for (var doc in _userStories) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['type'] != 'video') {
        // వీడియోస్ కాకుండా కేవలం ఇమేజెస్ ని మాత్రమే
        String url = data['storyUrl']?.toString() ?? "";
        if (url.isNotEmpty && url.startsWith('http')) {
          precacheImage(CachedNetworkImageProvider(url), context);
        }
      }
    }
  }

  void _showStory() {
    _animationController.stop();
    _animationController.reset();
    _videoController?.dispose();
    _videoController = null;

    if (_userStories.isEmpty) return;
    var currentStory =
        _userStories[_currentIndex].data() as Map<String, dynamic>;
    String storyUrl = currentStory['storyUrl']?.toString() ?? "";

    if (currentStory['type'] == 'video' && storyUrl.isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(storyUrl))
        ..initialize()
            .then((_) {
              if (mounted) {
                setState(() {});
                _videoController!.play();
                _animationController.duration =
                    _videoController!.value.duration;
                _animationController.forward();
              }
            })
            .catchError((e) {
              _nextStory();
              return null;
            });
    } else {
      // ఫోటో అయితే 60 సెకన్ల పాటు టైమ్ బార్ నిండుతుంది!
      _animationController.duration = const Duration(seconds: 60);
      _animationController.forward();
    }
    if (mounted) setState(() {});
  }

  void _nextStory() {
    _animationController.stop();
    _animationController.reset();
    if (_currentIndex < _userStories.length - 1) {
      setState(() => _currentIndex++);
      _showStory();
    } else {
      if (mounted) Navigator.pop(context);
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
    if (_isLoading)
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );

    var currentStory =
        _userStories[_currentIndex].data() as Map<String, dynamic>;
    String storyUrl = currentStory['storyUrl']?.toString() ?? "";
    String profilePic = currentStory['profilePic']?.toString() ?? "";
    String username = currentStory['username']?.toString() ?? "User";

    String postedTime = "Just now";
    if (currentStory['timestamp'] != null &&
        currentStory['timestamp'] is Timestamp) {
      postedTime = timeago.format(
        (currentStory['timestamp'] as Timestamp).toDate(),
        locale: 'en_short',
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          if (details.globalPosition.dx <
              MediaQuery.of(context).size.width / 3) {
            if (_currentIndex > 0) {
              _animationController.stop();
              _animationController.reset();
              setState(() => _currentIndex--);
              _showStory();
            }
          } else {
            _nextStory();
          }
        },
        child: Stack(
          children: [
            Center(
              child: currentStory['type'] == 'video'
                  ? (_videoController != null &&
                            _videoController!.value.isInitialized
                        ? AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          )
                        : const CircularProgressIndicator(color: Colors.white))
                  : CachedNetworkImage(
                      imageUrl: storyUrl,
                      fit: BoxFit
                          .contain, // 🌟 ఫోటోలు కట్ అవ్వకుండా ఉండటానికి 'contain' వాడాం
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                          size: 50,
                        ),
                      ),
                    ),
            ),
            Positioned(
              top: 50,
              left: 10,
              right: 10,
              child: Row(
                children: List.generate(_userStories.length, (index) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          double progress = 0.0;
                          if (index < _currentIndex) {
                            progress = 1.0;
                          } else if (index == _currentIndex) {
                            progress = _animationController.value;
                          }
                          return LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }),
              ),
            ),
            Positioned(
              top: 70,
              left: 15,
              right: 15,
              child: Row(
                children: [
                  SafeProfilePic(
                    base64String: profilePic,
                    radius: 18,
                    fallbackText: username.isNotEmpty ? username[0] : "U",
                  ),
                  const SizedBox(width: 10),
                  Text(
                    username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    postedTime,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
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
