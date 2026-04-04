// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🌟 ఓనర్ ఎవరో తెలుసుకోవడానికి
import 'package:timeago/timeago.dart' as timeago;
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

  // 🌟 డాక్యుమెంట్ స్నాప్‌షాట్స్ కాకుండా డైరెక్ట్ మ్యాప్ వాడుతున్నాం, ఎడిట్ చేయడానికి ఈజీగా ఉంటుంది
  List<Map<String, dynamic>> _userStories = [];
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
    String ownerId =
        widget.user['uid']?.toString() ??
        widget.user['ownerId']?.toString() ??
        "";
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
          // 🌟 స్టోరీ ఐడీ (storyId) ని కూడా డేటాలోకి కలుపుతున్నాం
          _userStories = snapshot.docs.map((doc) {
            var data = doc.data();
            data['storyId'] = doc.id;
            return data;
          }).toList();
          _isLoading = false;
        });

        _preloadImages();
        _showStory();
      }
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  void _preloadImages() {
    for (var data in _userStories) {
      if (data['type'] != 'video') {
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
    var currentStory = _userStories[_currentIndex];
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
      _animationController.duration = const Duration(seconds: 30);
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

  // 🌟 ఎడిట్ ఫంక్షన్
  void _editStory(String storyId, String currentCaption) {
    // డైలాగ్ వచ్చినప్పుడు స్టోరీ ఆగిపోవాలి
    _animationController.stop();
    _videoController?.pause();

    TextEditingController captionCtrl = TextEditingController(
      text: currentCaption,
    );
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Caption"),
        content: TextField(
          controller: captionCtrl,
          decoration: const InputDecoration(hintText: "Enter new caption"),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _animationController.forward(); // మళ్ళీ ప్లే
              _videoController?.play();
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('stories')
                  .doc(storyId)
                  .update({'caption': captionCtrl.text.trim()});
              if (mounted) {
                setState(() {
                  _userStories[_currentIndex]['caption'] = captionCtrl.text
                      .trim();
                });
                Navigator.pop(ctx);
                _animationController.forward(); // మళ్ళీ ప్లే
                _videoController?.play();
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // 🌟 డిలీట్ ఫంక్షన్
  void _deleteStory(String storyId) {
    _animationController.stop();
    _videoController?.pause();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Story?"),
        content: const Text("Are you sure you want to delete this story?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _animationController.forward();
              _videoController?.play();
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('stories')
                  .doc(storyId)
                  .delete();
              if (mounted) {
                Navigator.pop(ctx);
                setState(() {
                  _userStories.removeAt(
                    _currentIndex,
                  ); // లిస్ట్ లోంచి తీసేస్తున్నాం
                  if (_userStories.isEmpty) {
                    Navigator.pop(context); // అన్నీ అయిపోతే స్క్రీన్ క్లోజ్
                  } else {
                    if (_currentIndex >= _userStories.length) {
                      _currentIndex = _userStories.length - 1;
                    }
                    _showStory(); // నెక్స్ట్ దానికి వెళ్తుంది
                  }
                });
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    var currentStory = _userStories[_currentIndex];
    String storyId = currentStory['storyId']?.toString() ?? "";
    String storyUrl = currentStory['storyUrl']?.toString() ?? "";
    String caption = currentStory['caption']?.toString() ?? "";

    String profilePic = widget.user['profilePic']?.toString() ?? "";
    String username = widget.user['username']?.toString() ?? "User";
    String ownerId = currentStory['ownerId']?.toString() ?? "";

    // 🌟 మీ సొంత స్టోరీనా కాదా అని చెక్ చేయడం
    String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    bool isOwner = ownerId == currentUid;

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
        onLongPress: () {
          _animationController.stop();
          _videoController?.pause();
        },
        onLongPressUp: () {
          _animationController.forward();
          _videoController?.play();
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
                      fit: BoxFit.contain,
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

            // 🌟 టైమ్ బార్
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

            // 🌟 టాప్ బార్: ప్రొఫైల్ + ఆప్షన్స్
            Positioned(
              top: 70,
              left: 15,
              right: 10,
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
                      fontSize: 16,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    postedTime,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
                    ),
                  ),
                  const Spacer(),

                  // 🌟 మీ సొంత స్టోరీ అయితే ఇక్కడ ఎడిట్/డిలీట్ 3-Dots వస్తాయి
                  if (isOwner)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      color: Colors.grey[900],
                      onSelected: (value) {
                        if (value == 'edit') _editStory(storyId, caption);
                        if (value == 'delete') _deleteStory(storyId);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text(
                            "Edit Caption",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            "Delete Story",
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),

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

            // 🌟 కింద క్యాప్షన్ చూపిస్తున్నాం
            if (caption.isNotEmpty)
              Positioned(
                bottom: 40,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54, // టెక్స్ట్ క్లియర్ గా కనబడటానికి
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    caption,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
