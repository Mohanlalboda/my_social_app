// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../widgets/cached_media_widget.dart';
import '../../widgets/safe_elements.dart';
import '../../services/social_service.dart';

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
    var story = currentStoryItems[currentStoryIndex];
    String storyId = story['storyId'];
    String ownerId = story['uid'];
    List likes = List.from(story['likes'] ?? []);

    bool isLiked = likes.contains(currentUid);

    setState(() {
      if (isLiked)
        likes.remove(currentUid);
      else
        likes.add(currentUid);
      currentStoryItems[currentStoryIndex]['likes'] = likes;
    });

    await SocialService.toggleStoryLike(
      storyId: storyId,
      ownerId: ownerId,
      likesArray: likes,
    );
  }

  // 🌟 ఎవరు లైక్ చేశారో చూపించే లిస్ట్
  void _showLikesList(List likes) {
    setState(() => _isPaused = true);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(15),
            child: Text(
              "Liked by",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(color: Colors.white24),
          Expanded(
            child: likes.isEmpty
                ? const Center(
                    child: Text(
                      "No likes yet",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: likes.length,
                    itemBuilder: (ctx, i) => FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(likes[i])
                          .get(),
                      builder: (context, snap) {
                        if (!snap.hasData) return const SizedBox();
                        var user = snap.data!.data() as Map<String, dynamic>;
                        return ListTile(
                          leading: SafeProfilePic(
                            base64String: user['profilePic'] ?? '',
                            radius: 18,
                            fallbackText: user['username'][0],
                          ),
                          title: Text(
                            user['username'],
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    ).then((_) => setState(() => _isPaused = false));
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

    if (action == 'edit')
      _editCaption(currentCaption);
    else if (action == 'delete')
      _deleteStory();
    else if (mounted)
      setState(() => _isPaused = false);
  }

  void _editCaption(String currentCaption) async {
    TextEditingController captionCtrl = TextEditingController(
      text: currentCaption,
    );
    bool? isSaved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Caption"),
        content: TextField(controller: captionCtrl, autofocus: true),
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
      await FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .update({'caption': captionCtrl.text.trim()});
      setState(
        () => currentStoryItems[currentStoryIndex]['caption'] = captionCtrl.text
            .trim(),
      );
    }
    setState(() => _isPaused = false);
  }

  void _deleteStory() async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Delete Story?"),
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
      await FirebaseFirestore.instance
          .collection('stories')
          .doc(currentStoryItems[currentStoryIndex]['storyId'])
          .delete();
      Navigator.pop(context);
    } else
      setState(() => _isPaused = false);
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

    if (currentStoryItems.isEmpty)
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text("No stories", style: TextStyle(color: Colors.white)),
        ),
      );

    var storyData = currentStoryItems[currentStoryIndex];
    bool isOwner = storyData['uid'] == currentUid;
    List likes = storyData['likes'] ?? [];
    bool isLiked = likes.contains(currentUid);

    // 🌟 THE FIX: ఇక్కడ టైమ్ ని క్యాలిక్యులేట్ చేస్తున్నాం
    String timeStr = "Just now";
    if (storyData['timestamp'] != null) {
      timeStr = timeago.format((storyData['timestamp'] as Timestamp).toDate());
    }

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
              child: CachedMediaWidget(
                key: ValueKey(storyData['storyUrl']),
                mediaUrl: storyData['storyUrl'],
                type: storyData['type'] ?? 'image',
                showAudioControl: true,
              ),
            ),

            // 🌟 Like & Viewers Logic (Bottom Center)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (storyData['caption'] != null &&
                        storyData['caption'].isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          storyData['caption'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ),

                    GestureDetector(
                      onTap: _toggleLike,
                      child: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : Colors.white,
                        size: 45,
                      ),
                    ),
                    const SizedBox(height: 5),

                    if (likes.isNotEmpty)
                      GestureDetector(
                        onTap: () => _showLikesList(likes),
                        child: Text(
                          "${likes.length} ${likes.length == 1 ? 'like' : 'likes'}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // 🌟 Top Progress Bar & Profile Info
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Row(
                    children: List.generate(
                      currentStoryItems.length,
                      (index) => Expanded(
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
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      children: [
                        SafeProfilePic(
                          base64String:
                              widget
                                  .usersWithStories[currentUserIndex]['profilePic'] ??
                              '',
                          radius: 18,
                          fallbackText: widget
                              .usersWithStories[currentUserIndex]['username'][0],
                        ),
                        const SizedBox(width: 10),
                        // 🌟 THE FIX: ఇక్కడ యూజర్‌నేమ్ కింద టైమ్ వచ్చేలా మార్చాం
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget
                                    .usersWithStories[currentUserIndex]['username'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                timeStr, // టైమ్ డిస్‌ప్లే
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isOwner)
                          IconButton(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                            ),
                            onPressed: () =>
                                _showStoryMenu(storyData['caption'] ?? ''),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
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
