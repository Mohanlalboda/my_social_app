// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../widgets/cached_media_widget.dart';
import '../../widgets/safe_elements.dart';

class StoryViewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> usersWithStories;
  final int initialUserIndex;

  const StoryViewScreen({
    super.key,
    required this.usersWithStories,
    required this.initialUserIndex,
  });

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> {
  late int currentUserIndex;
  int currentStoryIndex = 0;
  List<Map<String, dynamic>> currentStoryItems = [];

  Timer? _timer;
  double _percent = 0.0;
  bool _isPaused = false;
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    currentUserIndex = widget.initialUserIndex;
    _loadUserStories();
  }

  void _loadUserStories() async {
    String userId = widget.usersWithStories[currentUserIndex]['uid'];

    var snap = await FirebaseFirestore.instance
        .collection('stories')
        .where('uid', isEqualTo: userId)
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt')
        .get();

    if (mounted) {
      setState(() {
        currentStoryItems = snap.docs.map((doc) {
          var data = doc.data();
          data['storyId'] = doc.id;
          return data;
        }).toList();

        currentStoryIndex = 0;
        _percent = 0.0;
        _isLoading = false;
      });

      if (currentStoryItems.isNotEmpty) {
        _startTimer();
        _markAsSeen();
      } else {
        _nextUser();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();

    int durationMs = 50;
    if (currentStoryItems.isNotEmpty) {
      String type = currentStoryItems[currentStoryIndex]['type'] ?? 'image';
      if (type == 'video') durationMs = 150;
    }

    _timer = Timer.periodic(Duration(milliseconds: durationMs), (timer) {
      if (!_isPaused) {
        setState(() {
          if (_percent < 1.0) {
            _percent += 0.01;
          } else {
            _timer?.cancel();
            _nextStory();
          }
        });
      }
    });
  }

  void _nextStory() {
    if (currentStoryIndex < currentStoryItems.length - 1) {
      setState(() {
        currentStoryIndex++;
        _percent = 0.0;
      });
      _startTimer();
      _markAsSeen();
    } else {
      _nextUser();
    }
  }

  void _nextUser() {
    if (currentUserIndex < widget.usersWithStories.length - 1) {
      setState(() {
        currentUserIndex++;
        currentStoryItems = [];
        _isLoading = true;
      });
      _loadUserStories();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (currentStoryIndex > 0) {
      setState(() {
        currentStoryIndex--;
        _percent = 0.0;
      });
      _startTimer();
    } else if (currentUserIndex > 0) {
      setState(() {
        currentUserIndex--;
        currentStoryItems = [];
        _isLoading = true;
      });
      _loadUserStories();
    } else {
      Navigator.pop(context);
    }
  }

  void _markAsSeen() {
    if (currentStoryItems.isEmpty) return;
    String storyId = currentStoryItems[currentStoryIndex]['storyId'];
    FirebaseFirestore.instance.collection('stories').doc(storyId).update({
      'viewers': FieldValue.arrayUnion([currentUid]),
    });
  }

  void _toggleLike() async {
    if (currentStoryItems.isEmpty) return;

    String storyId = currentStoryItems[currentStoryIndex]['storyId'];
    List likes = currentStoryItems[currentStoryIndex]['likes'] ?? [];
    bool isLiked = likes.contains(currentUid);

    setState(() {
      if (isLiked) {
        likes.remove(currentUid);
      } else {
        likes.add(currentUid);
      }
      currentStoryItems[currentStoryIndex]['likes'] = likes;
    });

    if (isLiked) {
      await FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .update({
            'likes': FieldValue.arrayRemove([currentUid]),
          });
    } else {
      await FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .update({
            'likes': FieldValue.arrayUnion([currentUid]),
          });
    }
  }

  void _showStoryMenu(String currentCaption) async {
    setState(() => _isPaused = true);

    String? action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: const Text(
                "Edit Caption",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                "Delete Story",
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (action == 'edit') {
      _editCaption(currentCaption);
    } else if (action == 'delete') {
      _deleteStory();
    } else {
      if (mounted) setState(() => _isPaused = false);
    }
  }

  void _editCaption(String currentCaption) async {
    TextEditingController captionCtrl = TextEditingController(
      text: currentCaption,
    );

    bool? isSaved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Caption"),
        content: TextField(
          controller: captionCtrl,
          decoration: const InputDecoration(hintText: "Write a caption..."),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (isSaved == true) {
      String storyId = currentStoryItems[currentStoryIndex]['storyId'];
      String newCaption = captionCtrl.text.trim();
      await FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .update({'caption': newCaption});

      if (mounted) {
        setState(
          () => currentStoryItems[currentStoryIndex]['caption'] = newCaption,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Caption Updated!")));
      }
    }
    if (mounted) setState(() => _isPaused = false);
  }

  void _deleteStory() async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Delete Story?"),
            content: const Text("Are you sure you want to delete this story?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  "Delete",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      String storyId = currentStoryItems[currentStoryIndex]['storyId'];
      await FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .delete();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Story Deleted!")));
      Navigator.pop(context);
    } else {
      if (mounted) setState(() => _isPaused = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );

    if (currentStoryItems.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text(
            "No active stories",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    var storyData = currentStoryItems[currentStoryIndex];
    bool isOwner =
        storyData['uid'] == currentUid || storyData['ownerId'] == currentUid;
    String type = storyData['type'] ?? 'image';

    String timeStr = "Just now";
    if (storyData['timestamp'] != null)
      timeStr = timeago.format((storyData['timestamp'] as Timestamp).toDate());

    String caption = storyData['caption'] ?? "";
    String username =
        widget.usersWithStories[currentUserIndex]['username'] ??
        storyData['username'] ??
        "User";
    String profilePic =
        widget.usersWithStories[currentUserIndex]['profilePic'] ??
        storyData['profilePic'] ??
        "";

    List likes = storyData['likes'] ?? [];
    bool isLiked = likes.contains(currentUid);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) => setState(() => _isPaused = true),
        onLongPressEnd: (_) => setState(() => _isPaused = false),
        onTapUp: (details) {
          double width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3)
            _previousStory();
          else
            _nextStory();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                onInteractionStart: (_) => setState(() => _isPaused = true),
                onInteractionEnd: (_) => setState(() => _isPaused = false),
                child: CachedMediaWidget(
                  key: ValueKey(storyData['storyUrl']),
                  mediaUrl: storyData['storyUrl'],
                  type: type,
                  showAudioControl: true,
                ),
              ),
            ),

            if (caption.isNotEmpty)
              Positioned(
                bottom: 100,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    caption,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),

            // 🌟 Like Button (Right Bottom)
            Positioned(
              bottom: 20,
              right: 15,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? const Color(0xFFFD1D1D) : Colors.white,
                      size: 35,
                    ),
                  ),
                  if (likes.isNotEmpty)
                    Text(
                      likes.length.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),

            Positioned(
              top: 50,
              left: 10,
              right: 10,
              child: Row(
                children: List.generate(currentStoryItems.length, (index) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: LinearProgressIndicator(
                        value: index < currentStoryIndex
                            ? 1.0
                            : (index == currentStoryIndex ? _percent : 0.0),
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                        minHeight: 2,
                      ),
                    ),
                  );
                }),
              ),
            ),

            Positioned(
              top: 70,
              left: 15,
              right: 10,
              child: Row(
                children: [
                  SafeProfilePic(
                    base64String: profilePic,
                    radius: 20,
                    fallbackText: username[0],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 🌟 Edit Menu (Owner Only)
                  if (isOwner)
                    IconButton(
                      icon: const Icon(
                        Icons.more_vert,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => _showStoryMenu(caption),
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
          ],
        ),
      ),
    );
  }
}
