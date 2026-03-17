// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../widgets/safe_elements.dart'; // 🌟 క్రాష్ అవ్వకుండా ఉండటానికి ఇది యాడ్ చేశాం

class StoryScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const StoryScreen({super.key, required this.user});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  VideoPlayerController? _videoController;
  int _currentIndex = 0;
  List<DocumentSnapshot> _userStories = [];
  Timer? _timer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
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
        _showStory();
      }
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  void _showStory() {
    _timer?.cancel();
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
                _videoController!.addListener(() {
                  if (_videoController!.value.position ==
                      _videoController!.value.duration) {
                    _nextStory();
                  }
                });
              }
            })
            .catchError((e) {
              _nextStory();
              return null;
            });
    } else {
      _timer = Timer(const Duration(seconds: 5), () => _nextStory());
    }
    if (mounted) setState(() {});
  }

  void _nextStory() {
    if (_currentIndex < _userStories.length - 1) {
      setState(() => _currentIndex++);
      _showStory();
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
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

    // 🌟 సేఫ్ టైమ్ స్టాంప్ చెక్
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
                  : Image.network(
                      storyUrl,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.broken_image,
                        color: Colors.white,
                        size: 50,
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
                      child: LinearProgressIndicator(
                        value: index == _currentIndex
                            ? null
                            : (index < _currentIndex ? 1.0 : 0.0),
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
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
                  // 🌟 క్రాష్ అవ్వకుండా SafeProfilePic వాడాం
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
