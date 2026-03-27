// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../widgets/safe_elements.dart';

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

  // 🌟 మ్యాజిక్ 1: డాక్యుమెంట్స్ ని డైరెక్ట్ గా కాకుండా, ఎడిట్ చేసుకోవడానికి వీలుగా Map లిస్ట్ లాగా మార్చుకున్నాం
  List<Map<String, dynamic>> currentStoryItems = [];

  Timer? _timer;
  double _percent = 0.0;
  bool _isPaused = false;
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

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
        .orderBy('timestamp', descending: false)
        .get();

    if (mounted) {
      setState(() {
        // 🌟 డేటాని మనకు కావాల్సినట్టు కన్వర్ట్ చేసి పెట్టుకుంటున్నాం
        currentStoryItems = snap.docs.map((doc) {
          var data = doc.data();
          data['storyId'] = doc.id; // ఐడీని కూడా లోపలే సేవ్ చేస్తున్నాం
          return data;
        }).toList();

        currentStoryIndex = 0;
        _percent = 0.0;
      });
      _startTimer();
      _markAsSeen();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
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
      });
      _loadUserStories();
    }
  }

  void _markAsSeen() {
    if (currentStoryItems.isEmpty) return;
    String storyId = currentStoryItems[currentStoryIndex]['storyId'];
    FirebaseFirestore.instance.collection('stories').doc(storyId).update({
      'viewers': FieldValue.arrayUnion([currentUid]),
    });
  }

  // 🌟 మ్యాజిక్ 2: బాటమ్ షీట్ లో ఏ ఆప్షన్ నొక్కారో తెలుసుకొని దాని ప్రకారం పాజ్ ని కంట్రోల్ చేస్తున్నాం
  void _showStoryMenu(String currentCaption) async {
    setState(() => _isPaused = true); // మెనూ ఓపెన్ అవ్వగానే ఆగిపోతుంది

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
              onTap: () => Navigator.pop(ctx, 'edit'), // ఎడిట్ పంపుతాం
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                "Delete Story",
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => Navigator.pop(ctx, 'delete'), // డిలీట్ పంపుతాం
            ),
          ],
        ),
      ),
    );

    // షీట్ క్లోజ్ అయ్యాక ఏం చేయాలో ఇక్కడ డిసైడ్ అవుతుంది
    if (action == 'edit') {
      _editCaption(currentCaption);
    } else if (action == 'delete') {
      _deleteStory();
    } else {
      // ఒకవేళ పక్కన నొక్కి క్యాన్సిల్ చేస్తే, అప్పుడు మళ్ళీ స్టోరీ ప్లే అవ్వాలి
      if (mounted) setState(() => _isPaused = false);
    }
  }

  // 🌟 3. EDIT CAPTION LOGIC (UI Update Fixed)
  void _editCaption(String currentCaption) async {
    // ఇక్కడికి వచ్చేసరికి ఆల్రెడీ _isPaused = true లోనే ఉంది కాబట్టి స్టోరీ బ్యాక్‌గ్రౌండ్ లో ప్లే అవ్వదు.
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

      // డేటాబేస్ లో సేవ్ చేయడం
      await FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .update({'caption': newCaption});

      if (mounted) {
        setState(() {
          // 🌟 UI లో వెంటనే అప్‌డేట్ అవ్వడానికి మన లోకల్ లిస్ట్ ని మారుస్తున్నాం
          currentStoryItems[currentStoryIndex]['caption'] = newCaption;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Caption Updated!")));
      }
    }

    // డైలాగ్ సేవ్ చేసినా, క్యాన్సిల్ చేసినా మళ్ళీ స్టోరీ ప్లే అవ్వాలి
    if (mounted) setState(() => _isPaused = false);
  }

  // 🌟 4. DELETE STORY LOGIC
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
    if (currentStoryItems.isEmpty)
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );

    var storyData = currentStoryItems[currentStoryIndex];
    bool isOwner = storyData['ownerId'] == currentUid;

    String timeStr = "Just now";
    if (storyData['timestamp'] != null) {
      timeStr = timeago.format((storyData['timestamp'] as Timestamp).toDate());
    }

    String caption = storyData['caption'] ?? "";

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) => setState(() => _isPaused = true),
        onLongPressEnd: (_) => setState(() => _isPaused = false),
        onTapUp: (details) {
          double width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3) {
            _previousStory();
          } else {
            _nextStory();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // IMAGE (ZOOMABLE)
            Center(
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                onInteractionStart: (_) => setState(() => _isPaused = true),
                onInteractionEnd: (_) => setState(() => _isPaused = false),
                child: CachedNetworkImage(
                  imageUrl: storyData['storyUrl'],
                  fit: BoxFit.contain,
                  width: double.infinity,
                ),
              ),
            ),

            // CAPTION OVERLAY 🌟
            if (caption.isNotEmpty)
              Positioned(
                bottom: 50,
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

            // PROGRESS BARS
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

            // HEADER (PROFILE, NAME, TIME, OPTIONS) 🌟
            Positioned(
              top: 70,
              left: 15,
              right: 10,
              child: Row(
                children: [
                  SafeProfilePic(
                    base64String: storyData['profilePic'],
                    radius: 20,
                    fallbackText: storyData['username'][0],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storyData['username'],
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
                  if (isOwner)
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
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
