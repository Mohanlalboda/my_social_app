// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/safe_elements.dart';
import 'other_user_profile_screen.dart';
import 'comments_screen.dart';

// 🌟 గ్లోబల్ మ్యూట్ వేరియబుల్
bool globalIsMuted = false;

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  int _currentPage = 0;

  Future<void> _refreshReels() async {
    setState(() {});
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: RefreshIndicator(
        onRefresh: _refreshReels,
        color: Colors.blue,
        backgroundColor: bgColor,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .where('type', isEqualTo: 'video')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return Center(
                child: Text(
                  "Error: ${snapshot.error}",
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
              );
            if (!snapshot.hasData)
              return Center(
                child: CircularProgressIndicator(
                  color: isDark ? Colors.white : Colors.black,
                ),
              );

            var reels = snapshot.data!.docs;
            if (reels.isEmpty)
              return Center(
                child: Text(
                  "No Reels Found. 🎬",
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              );

            return PageView.builder(
              scrollDirection: Axis.vertical,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemCount: reels.length,
              itemBuilder: (context, index) {
                var data = reels[index].data() as Map<String, dynamic>;
                data['postId'] = reels[index].id;
                return ReelItem(
                  key: ValueKey(data['postId']),
                  reel: data,
                  index: index,
                  currentPage: _currentPage,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class ReelItem extends StatefulWidget {
  final Map<String, dynamic> reel;
  final int index;
  final int currentPage;
  const ReelItem({
    super.key,
    required this.reel,
    required this.index,
    required this.currentPage,
  });

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  bool isLiked = false;
  bool isSaved = false;
  bool showHeart = false;
  bool isFollowing = false;
  int likeCount = 0;

  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _initLikeStatus();
    _initSaveStatus();
    _initFollowStatus();
    _checkAndInit();
  }

  void _initFollowStatus() async {
    if (widget.reel['ownerId'] == currentUid) return;

    var doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .get();
    if (doc.exists) {
      List followingList = doc.data()?['following'] ?? [];
      if (mounted) {
        setState(() {
          isFollowing = followingList.contains(widget.reel['ownerId']);
        });
      }
    }
  }

  void _initLikeStatus() {
    List likes = widget.reel['likes'] ?? [];
    isLiked = likes.contains(currentUid);
    likeCount = likes.length;
  }

  void _initSaveStatus() {
    List savedBy = widget.reel['savedBy'] ?? [];
    isSaved = savedBy.contains(currentUid);
  }

  void _checkAndInit() {
    bool shouldBeLoaded =
        (widget.index >= widget.currentPage - 1 &&
        widget.index <= widget.currentPage + 2);

    if (shouldBeLoaded && _controller == null) {
      String url =
          (widget.reel['postData'] is List &&
              widget.reel['postData'].isNotEmpty)
          ? widget.reel['postData'][0]
          : (widget.reel['storyUrl'] ?? "");

      if (url.isNotEmpty) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(url))
          ..initialize().then((_) {
            if (mounted) {
              setState(() {
                _isInitialized = true;
                _controller!.setLooping(true);
                _controller!.setVolume(globalIsMuted ? 0.0 : 1.0);
                if (widget.index == widget.currentPage) _controller!.play();
              });
            }
          });
      }
    }
  }

  @override
  void didUpdateWidget(ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkAndInit();
    if (_isInitialized && _controller != null) {
      if (widget.index == widget.currentPage) {
        _controller!.setVolume(globalIsMuted ? 0.0 : 1.0);
        _controller!.play();
      } else {
        _controller!.pause();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggleMute() {
    if (_controller == null) return;
    setState(() {
      globalIsMuted = !globalIsMuted;
      _controller!.setVolume(globalIsMuted ? 0.0 : 1.0);
    });
  }

  void _handleLike() async {
    setState(() {
      isLiked ? likeCount-- : likeCount++;
      isLiked = !isLiked;
    });
    var ref = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.reel['postId']);
    isLiked
        ? await ref.update({
            'likes': FieldValue.arrayUnion([currentUid]),
          })
        : await ref.update({
            'likes': FieldValue.arrayRemove([currentUid]),
          });
  }

  void _handleSave() async {
    setState(() => isSaved = !isSaved);
    var ref = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.reel['postId']);
    isSaved
        ? await ref.update({
            'savedBy': FieldValue.arrayUnion([currentUid]),
          })
        : await ref.update({
            'savedBy': FieldValue.arrayRemove([currentUid]),
          });
  }

  void _handleFollow() async {
    setState(() => isFollowing = !isFollowing);

    String targetUserId = widget.reel['ownerId'];
    var currentUserRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid);
    var targetUserRef = FirebaseFirestore.instance
        .collection('users')
        .doc(targetUserId);

    if (isFollowing) {
      await currentUserRef.update({
        'following': FieldValue.arrayUnion([targetUserId]),
      });
      await targetUserRef.update({
        'followers': FieldValue.arrayUnion([currentUid]),
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Following ${widget.reel['username']}")),
        );
    } else {
      await currentUserRef.update({
        'following': FieldValue.arrayRemove([targetUserId]),
      });
      await targetUserRef.update({
        'followers': FieldValue.arrayRemove([currentUid]),
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unfollowed ${widget.reel['username']}")),
        );
    }
  }

  void _shareReel() {
    String url =
        (widget.reel['postData'] is List && widget.reel['postData'].isNotEmpty)
        ? widget.reel['postData'][0]
        : (widget.reel['storyUrl'] ?? "");

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Text(
                "Share with Friends",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(
              height: 100,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('uid', isNotEqualTo: currentUid)
                    .limit(10)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  var users = snapshot.data!.docs;
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      var user = users[index].data() as Map<String, dynamic>;
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Sent to ${user['username']}! 🚀"),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            children: [
                              SafeProfilePic(
                                base64String: user['profilePic'],
                                radius: 30,
                                fallbackText: (user['username'] ?? "U")[0],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                user['username'] ?? "User",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.white),
              title: const Text(
                "Share to other apps",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                Share.share(
                  'Check out this awesome reel on My Social App! 🎬\n\n$url',
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  void _deleteReel() async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Reel?"),
        content: const Text("Are you sure you want to delete this reel?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm) {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.reel['postId'])
          .delete();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Reel deleted!")));
    }
  }

  void _editReel() {
    TextEditingController editController = TextEditingController(
      text: widget.reel['caption'],
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Caption"),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(hintText: "Enter new caption"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.reel['postId'])
                  .update({'caption': editController.text});
              if (!mounted) return;
              setState(() => widget.reel['caption'] = editController.text);
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isOwner = widget.reel['ownerId'] == currentUid;

    return VisibilityDetector(
      key: Key(widget.reel['postId']),
      onVisibilityChanged: (info) {
        if (!mounted || _controller == null || !_isInitialized) return;
        if (info.visibleFraction > 0.8) {
          _controller!.setVolume(globalIsMuted ? 0.0 : 1.0);
          _controller!.play();
          setState(() {});
        } else {
          if (_controller!.value.isPlaying) _controller!.pause();
        }
      },
      child: GestureDetector(
        onTap: () {
          if (_isInitialized && _controller != null) {
            _controller!.value.isPlaying
                ? _controller!.pause()
                : _controller!.play();
            setState(() {});
          }
        },
        onDoubleTap: () {
          if (!isLiked) _handleLike();
          setState(() => showHeart = true);
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) setState(() => showHeart = false);
          });
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            _isInitialized && _controller != null
                ? Center(
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white24),
                  ),

            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black54,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black87,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.2, 0.6, 1.0],
                ),
              ),
            ),

            if (_isInitialized &&
                _controller != null &&
                !_controller!.value.isPlaying)
              const Center(
                child: Icon(Icons.play_arrow, color: Colors.white54, size: 80),
              ),

            if (showHeart)
              Center(
                child: TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0.5, end: 1.2),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, val, child) => Transform.scale(
                    scale: val,
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 100,
                    ),
                  ),
                ),
              ),

            // 🌟 Top Bar: Profile (Left) & Follow (Right)
            Positioned(
              top: 50,
              left: 15,
              right: 15,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OtherUserProfileScreen(
                              uid: widget.reel['ownerId'],
                            ),
                          ),
                        ),
                        child: SafeProfilePic(
                          base64String: widget.reel['profilePic'],
                          radius: 20,
                          fallbackText: (widget.reel['username'] ?? "U")[0],
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OtherUserProfileScreen(
                              uid: widget.reel['ownerId'],
                            ),
                          ),
                        ),
                        child: Text(
                          widget.reel['username'] ?? "User",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 🌟 Follow button వేరే వాళ్ళ వీడియోలకు మాత్రమే వస్తుంది.
                  if (!isOwner)
                    GestureDetector(
                      onTap: _handleFollow,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white),
                          borderRadius: BorderRadius.circular(8),
                          color: isFollowing
                              ? Colors.white
                              : Colors.transparent,
                        ),
                        child: Text(
                          isFollowing ? "Following" : "Follow",
                          style: TextStyle(
                            color: isFollowing ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Positioned(
              bottom: 25,
              left: 15,
              right: 70,
              child: Text(
                widget.reel['caption'] ?? "",
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),

            // 🌟 Right Side Buttons Column
            Positioned(
              right: 15,
              bottom: 40, // 🌟 కిందికి కాస్త జరిపాను, కొత్త ఆప్షన్స్ పట్టడానికి
              child: Column(
                children: [
                  IconButton(
                    icon: Icon(
                      globalIsMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: _toggleMute,
                  ),
                  const SizedBox(height: 10),

                  IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : Colors.white,
                      size: 32,
                    ),
                    onPressed: _handleLike,
                  ),
                  Text(
                    "$likeCount",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  IconButton(
                    icon: const Icon(
                      Icons.comment_outlined,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommentsScreen(
                          postId: widget.reel['postId'],
                          postOwnerId: widget.reel['ownerId'],
                          isReel: true,
                        ),
                      ),
                    ),
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .doc(widget.reel['postId'])
                        .collection('comments')
                        .snapshots(),
                    builder: (context, snapshot) {
                      int commentsCount = snapshot.hasData
                          ? snapshot.data!.docs.length
                          : 0;
                      return Text(
                        "$commentsCount",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  IconButton(
                    icon: const Icon(
                      Icons.share,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: _shareReel,
                  ),
                  const SizedBox(height: 10),

                  IconButton(
                    icon: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: _handleSave,
                  ),

                  // 🌟 మ్యాజిక్ ఇక్కడే జరిగింది: మీ సొంత వీడియో అయితే Save కింద ఈ ఆప్షన్స్ వస్తాయి
                  if (isOwner) ...[
                    const SizedBox(height: 5),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: Colors.white,
                        size: 30,
                      ),
                      onSelected: (value) {
                        if (value == 'edit') _editReel();
                        if (value == 'delete') _deleteReel();
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text("Edit Caption"),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            "Delete Reel",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
