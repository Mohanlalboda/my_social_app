// lib/screens/home/story_view_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 🌟 THE FIX: Caching Import
import '../../services/firestore_methods.dart';

class StoryViewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> userStories;
  const StoryViewScreen({super.key, required this.userStories});

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> {
  int _currentStoryIndex = 0;
  double _progressValue = 0.0;
  Timer? _storyTimer;
  VideoPlayerController? _mediaPlayer;
  bool _isPlayerInitialized = false;
  bool _isLiked = false;
  bool _isMuted = false;

  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _setupCurrentStory();
  }

  void _setupCurrentStory() {
    _storyTimer?.cancel();
    _mediaPlayer?.dispose();
    _mediaPlayer = null;
    _progressValue = 0.0;
    _isPlayerInitialized = false;

    if (widget.userStories.isEmpty) return;

    var currentStory = widget.userStories[_currentStoryIndex];
    String storyType = currentStory['type'] ?? 'image';
    String storyUrl = currentStory['storyUrl'] ?? '';
    String storyId = currentStory['storyId'] ?? '';

    if (storyId.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .update({
            'viewers': FieldValue.arrayUnion([currentUid]),
          })
          .catchError((e) => debugPrint("Error updating story views: $e"));
    }

    setState(() {
      _isLiked = (currentStory['likes'] ?? []).contains(currentUid);
    });

    if ((storyType == "video" || storyType == "voice") &&
        storyUrl.isNotEmpty &&
        storyUrl.startsWith('http')) {
      _mediaPlayer = VideoPlayerController.networkUrl(Uri.parse(storyUrl))
        ..initialize()
            .then((_) {
              if (mounted) {
                setState(() {
                  _isPlayerInitialized = true;
                });
                _mediaPlayer?.setVolume(_isMuted ? 0.0 : 1.0);
                _mediaPlayer?.play();
                int duration = _mediaPlayer!.value.duration.inSeconds;
                _startStoryTimer(duration > 5 ? duration : 5);
              }
            })
            .catchError((e) {
              debugPrint("🚨 Media Playback Error: $e");
              _startStoryTimer(5);
            });
    } else {
      setState(() {
        _isPlayerInitialized = true;
      });
      _startStoryTimer(5);
    }
  }

  void _startStoryTimer(int duration) {
    _storyTimer?.cancel();
    const int updateIntervalMs = 50;
    double step = updateIntervalMs / (duration * 1000);
    _storyTimer = Timer.periodic(
      const Duration(milliseconds: updateIntervalMs),
      (timer) {
        if (!mounted) return;
        setState(() {
          if (_progressValue >= 1.0) {
            timer.cancel();
            _nextStory();
          } else {
            _progressValue += step;
          }
        });
      },
    );
  }

  void _nextStory() {
    if (_currentStoryIndex < widget.userStories.length - 1) {
      setState(() => _currentStoryIndex++);
      _setupCurrentStory();
    } else {
      _cleanupAndPop();
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      setState(() => _currentStoryIndex--);
      _setupCurrentStory();
    } else {
      _setupCurrentStory();
    }
  }

  void _cleanupAndPop() {
    _storyTimer?.cancel();
    _mediaPlayer?.dispose();
    if (mounted) Navigator.pop(context);
  }

  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  void _showEditCaptionDialog(String storyId, String currentCaption) {
    _storyTimer?.cancel();
    if (_mediaPlayer != null) {
      _mediaPlayer!.pause();
    }

    TextEditingController captionController = TextEditingController(
      text: currentCaption,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'Edit Caption',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: captionController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Enter new caption...",
            hintStyle: const TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[700]!),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.blueAccent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resumeStory();
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              String newCaption = captionController.text;
              Navigator.pop(ctx);

              await FirebaseFirestore.instance
                  .collection('stories')
                  .doc(storyId)
                  .update({'textContent': newCaption});

              if (!context.mounted) return;
              setState(() {
                widget.userStories[_currentStoryIndex]['textContent'] =
                    newCaption;
              });

              _resumeStory();
            },
            child: const Text(
              'Save',
              style: TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resumeStory() {
    if (!mounted) return;
    int duration = 5;
    if (_mediaPlayer != null) {
      _mediaPlayer!.play();
      duration = _mediaPlayer!.value.duration.inSeconds;
    }

    double remainingProgress = 1.0 - _progressValue;
    if (remainingProgress <= 0) {
      _nextStory();
      return;
    }
    _startStoryTimer(duration);
  }

  void _showViewersSheet(List viewers) {
    _storyTimer?.cancel();
    _mediaPlayer?.pause();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withAlpha((0.9 * 255).round()),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.5,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                '👁️ Viewed by ${viewers.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const Divider(color: Colors.white24, height: 30),
              Expanded(
                child: viewers.isEmpty
                    ? const Center(
                        child: Text(
                          "No views yet 🏜️",
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: viewers.length,
                        itemBuilder: (listCtx, index) {
                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(viewers[index])
                                .get(),
                            builder: (futureCtx, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const ListTile(
                                  title: Text(
                                    "Loading...",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                );
                              }
                              if (!snapshot.hasData || !snapshot.data!.exists)
                                return const SizedBox();
                              var data =
                                  snapshot.data!.data() as Map<String, dynamic>;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.grey[800],
                                  // 🌟 THE FIX: Viewers Profile Pic Cache
                                  backgroundImage: CachedNetworkImageProvider(
                                    data['profilePic']?.toString().isNotEmpty ==
                                            true
                                        ? data['profilePic']
                                        : 'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                                  ),
                                ),
                                title: Text(
                                  data['username'] ?? 'User',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      _resumeStory();
    });
  }

  void _showReplySheet(String targetUid) {
    _storyTimer?.cancel();
    _mediaPlayer?.pause();

    final TextEditingController replyController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black.withAlpha((0.85 * 255).round()),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children:
                      [
                            '😂',
                            '😮',
                            '😍',
                            '😢',
                            '👏',
                            '🔥',
                            '🙌',
                            '❤️',
                            '👍',
                            '🎉',
                            '✨',
                            '💯',
                            '🚀',
                          ]
                          .map(
                            (emoji) => GestureDetector(
                              onTap: () async {
                                final scaffoldMessenger = ScaffoldMessenger.of(
                                  context,
                                );
                                Navigator.pop(ctx);

                                await FirestoreMethods().sendMessage(
                                  targetUid,
                                  "Reacted to your story: $emoji",
                                );

                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text("Reaction Sent $emoji"),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10.0,
                                ),
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 32),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: replyController,
                      style: const TextStyle(color: Colors.white),
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Reply to story...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white12,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: () async {
                        if (replyController.text.trim().isNotEmpty) {
                          String msg = replyController.text.trim();

                          final scaffoldMessenger = ScaffoldMessenger.of(
                            context,
                          );
                          Navigator.pop(ctx);

                          await FirestoreMethods().sendMessage(
                            targetUid,
                            "Replied to your story: $msg",
                          );

                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text("Reply Sent 🚀"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    ).then((_) {
      _resumeStory();
    });
  }

  void _showShareSheet(String storyUrl) {
    _storyTimer?.cancel();
    _mediaPlayer?.pause();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Share to...",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .snapshots(),
                  builder: (streamCtx, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    var users = snapshot.data!.docs
                        .where((doc) => doc.id != currentUid)
                        .toList();

                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (listCtx, index) {
                        var user = users[index].data() as Map<String, dynamic>;
                        return ListTile(
                          leading: CircleAvatar(
                            // 🌟 THE FIX: Share Sheet Profile Pic Cache
                            backgroundImage: CachedNetworkImageProvider(
                              user['profilePic']?.toString().isNotEmpty == true
                                  ? user['profilePic']
                                  : 'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                            ),
                          ),
                          title: Text(
                            user['username'] ?? '',
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () async {
                              final scaffoldMessenger = ScaffoldMessenger.of(
                                context,
                              );
                              Navigator.pop(ctx);

                              String uId = users[index].id;
                              await FirestoreMethods().sendMessage(
                                uId,
                                "Shared a Story: $storyUrl",
                              );

                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text("Story Shared! 🚀"),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            child: const Text(
                              "Send",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      _resumeStory();
    });
  }

  void _showMenuOptions(
    bool isMyStory,
    String storyId,
    String targetUid,
    String currentCaption,
  ) {
    _storyTimer?.cancel();
    _mediaPlayer?.pause();

    bool shouldResume = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: isMyStory
            ? [
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blueAccent),
                  title: const Text(
                    "Edit Caption",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    shouldResume = false;
                    Navigator.pop(ctx);
                    _showEditCaptionDialog(storyId, currentCaption);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    "Delete Story",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    shouldResume = false;
                    final navigator = Navigator.of(context);
                    Navigator.pop(ctx);

                    await FirebaseFirestore.instance
                        .collection('stories')
                        .doc(storyId)
                        .delete();

                    _storyTimer?.cancel();
                    _mediaPlayer?.dispose();
                    navigator.pop();
                  },
                ),
              ]
            : [
                ListTile(
                  leading: const Icon(
                    Icons.flag_rounded,
                    color: Colors.orangeAccent,
                  ),
                  title: const Text(
                    "Report Story",
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Story reported. 🛑")),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.block_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    "Block User",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("User blocked. 🚫")),
                    );
                  },
                ),
              ],
      ),
    ).then((_) {
      if (shouldResume) {
        _resumeStory();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userStories.isEmpty) return const Scaffold();

    var currentStory = widget.userStories[_currentStoryIndex];

    String username =
        currentStory['username'] ??
        currentStory['name'] ??
        currentStory['displayName'] ??
        'User';
    String profilePic = currentStory['profilePic'] ?? '';
    String storyUrl = currentStory['storyUrl'] ?? '';
    String thumbnailUrl = currentStory['thumbnailUrl'] ?? '';

    String textContent = currentStory['textContent'] ?? '';
    String storyType = currentStory['type'] ?? 'image';

    String storyCaption = (storyType == 'image' || storyType == 'video')
        ? textContent
        : '';

    List viewers = currentStory['viewers'] ?? [];
    bool isMyStory = currentUid == currentStory['uid'];

    String timeAgo = _getTimeAgo(currentStory['timestamp']);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTapUp: (details) {
              double width = MediaQuery.of(context).size.width;
              if (details.globalPosition.dy >
                  MediaQuery.of(context).size.height - 120)
                return;
              if (details.globalPosition.dx < width / 3)
                _previousStory();
              else
                _nextStory();
            },
            onVerticalDragUpdate: (details) {
              if (isMyStory && details.primaryDelta! < -10)
                _showViewersSheet(viewers);
              else if (details.primaryDelta! > 10)
                _cleanupAndPop();
            },
            child: Center(
              child: storyType == "text" && textContent.isNotEmpty
                  ? _buildTextStoryView(textContent)
                  : storyType == "voice"
                  ? _buildVoiceStoryView(textContent, profilePic)
                  : storyType == "video"
                  ? _buildVideoStoryView()
                  // 🌟 THE FIX: Main Story Image Caching
                  : CachedNetworkImage(
                      imageUrl: storyUrl,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                      errorWidget: (context, url, error) => const Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white38,
                        size: 60,
                      ),
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: List.generate(widget.userStories.length, (index) {
                      double viewValue = index < _currentStoryIndex
                          ? 1.0
                          : (index == _currentStoryIndex
                                ? _progressValue
                                : 0.0);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: LinearProgressIndicator(
                            value: viewValue,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        // 🌟 THE FIX: AppBar Profile Pic Caching
                        backgroundImage: CachedNetworkImageProvider(
                          profilePic.isNotEmpty
                              ? profilePic
                              : 'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeAgo,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),

                      if (storyType == 'video')
                        IconButton(
                          icon: Icon(
                            _isMuted ? Icons.volume_off : Icons.volume_up,
                            color: Colors.white,
                            size: 26,
                          ),
                          onPressed: () {
                            setState(() {
                              _isMuted = !_isMuted;
                              _mediaPlayer?.setVolume(_isMuted ? 0.0 : 1.0);
                            });
                          },
                        ),
                      IconButton(
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () => _showShareSheet(storyUrl),
                      ),

                      IconButton(
                        icon: const Icon(
                          Icons.more_vert,
                          color: Colors.white,
                          size: 26,
                        ),
                        onPressed: () => _showMenuOptions(
                          isMyStory,
                          currentStory['storyId'] ?? '',
                          currentStory['uid'] ?? '',
                          storyCaption,
                        ),
                      ),

                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 26,
                        ),
                        onPressed: _cleanupAndPop,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if ((storyType == "image" || storyType == "video") &&
              storyCaption.isNotEmpty)
            Positioned(
              bottom: 85,
              left: 15,
              right: isMyStory ? 80 : 15,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  storyCaption,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

          if (isMyStory)
            Positioned(
              bottom: 85,
              right: 15,
              child: GestureDetector(
                onTap: () {
                  _storyTimer?.cancel();
                  if (_mediaPlayer != null && _mediaPlayer!.value.isPlaying) {
                    _mediaPlayer!.pause();
                  }

                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    builder: (ctx) => SaveToHighlightSheet(
                      storyUrl: storyUrl,
                      storyType: storyType,
                      thumbnailUrl: thumbnailUrl,
                    ),
                  ).then((_) {
                    _resumeStory();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.red,
                    size: 28,
                  ),
                ),
              ),
            ),

          if (isMyStory)
            Positioned(
              bottom: 25,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => _showViewersSheet(viewers),
                child: const Center(
                  child: Text(
                    "Viewers",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            )
          else
            Positioned(
              bottom: 20,
              left: 15,
              right: 15,
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showReplySheet(currentStory['uid']),
                      child: Container(
                        height: 45,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white70, width: 1.2),
                          borderRadius: BorderRadius.circular(30),
                          color: Colors.black45,
                        ),
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          "Send message...",
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? Colors.red : Colors.white,
                      size: 32,
                    ),
                    onPressed: () async {
                      setState(() => _isLiked = !_isLiked);
                      await FirestoreMethods().likeStory(
                        currentStory['storyId'] ?? '',
                        currentUid,
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextStoryView(String combinedTextData) {
    List<String> parts = combinedTextData.split('|');
    List<Color> bgColors = parts.length > 1
        ? parts[1]
              .split(',')
              .map((hex) => Color(int.parse(hex, radix: 16)))
              .toList()
        : [Colors.purple, Colors.deepPurple];
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: bgColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 30),
      alignment: Alignment.center,
      child: Text(
        parts[0],
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildVideoStoryView() {
    if (_isPlayerInitialized && _mediaPlayer != null) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: _mediaPlayer!.value.size.width,
            height: _mediaPlayer!.value.size.height,
            child: VideoPlayer(_mediaPlayer!),
          ),
        ),
      );
    }
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }

  Widget _buildVoiceStoryView(String textContent, String profilePic) {
    bool isPlaying = (_isPlayerInitialized && _mediaPlayer != null)
        ? _mediaPlayer!.value.isPlaying
        : false;
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 55,
            backgroundColor: Colors.white24,
            child: CircleAvatar(
              radius: 51,
              // 🌟 THE FIX: Voice Story Profile Pic Caching
              backgroundImage: CachedNetworkImageProvider(
                profilePic.isNotEmpty
                    ? profilePic
                    : 'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
              ),
            ),
          ),
          const SizedBox(height: 35),
          Icon(
            Icons.mic_rounded,
            color: isPlaying ? Colors.greenAccent : Colors.white38,
            size: 70,
          ),
        ],
      ),
    );
  }
}

class SaveToHighlightSheet extends StatefulWidget {
  final String storyUrl;
  final String storyType;
  final String thumbnailUrl;
  const SaveToHighlightSheet({
    super.key,
    required this.storyUrl,
    required this.storyType,
    required this.thumbnailUrl,
  });

  @override
  State<SaveToHighlightSheet> createState() => _SaveToHighlightSheetState();
}

class _SaveToHighlightSheetState extends State<SaveToHighlightSheet> {
  final TextEditingController _titleController = TextEditingController();
  bool _isCreatingNew = false;
  bool _isLoading = false;

  void _addToExisting(String highlightId) async {
    setState(() => _isLoading = true);
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await FirebaseFirestore.instance
          .collection('highlights')
          .doc(highlightId)
          .update({
            'mediaUrls': FieldValue.arrayUnion([widget.storyUrl]),
          });

      navigator.pop();
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text("Added to Highlight! 🌟"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _createNew() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      String newId = DateTime.now().millisecondsSinceEpoch.toString();

      String cover = widget.storyType == 'video'
          ? widget.thumbnailUrl
          : (widget.storyType == 'image' ? widget.storyUrl : '');

      await FirebaseFirestore.instance.collection('highlights').doc(newId).set({
        'highlightId': newId,
        'uid': uid,
        'name': _titleController.text.trim(),
        'coverUrl': cover,
        'mediaUrls': [widget.storyUrl],
        'timestamp': FieldValue.serverTimestamp(),
      });

      navigator.pop();
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text("New Highlight Created! 🎉"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Add to Highlights 🌟",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),

          if (_isCreatingNew) ...[
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Highlight Name",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                      ),
                      onPressed: _createNew,
                      child: const Text(
                        "Save",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
          ] else ...[
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.add, color: Colors.white),
              ),
              title: const Text(
                "Create New Highlight",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () => setState(() => _isCreatingNew = true),
            ),
            const Divider(),
            SizedBox(
              height: 250,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('highlights')
                    .where('uid', isEqualTo: currentUid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  var docs = snapshot.data!.docs;

                  if (docs.isEmpty)
                    return const Center(
                      child: Text(
                        "No existing highlights. Create one! 👇",
                        style: TextStyle(color: Colors.grey),
                      ),
                    );

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var data = docs[index].data() as Map<String, dynamic>;
                      String cover = data['coverUrl'] ?? '';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[800],
                          // 🌟 THE FIX: Highlight Cover Image Caching
                          backgroundImage: cover.isNotEmpty
                              ? CachedNetworkImageProvider(cover)
                              : null,
                          child: cover.isEmpty
                              ? const Icon(
                                  Icons.movie_creation,
                                  color: Colors.white54,
                                )
                              : null,
                        ),
                        title: Text(
                          data['name'] ?? 'Highlight',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        trailing: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.add_circle_outline,
                                color: Colors.blueAccent,
                              ),
                        onTap: () => _addToExisting(docs[index].id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 15),
        ],
      ),
    );
  }
}
