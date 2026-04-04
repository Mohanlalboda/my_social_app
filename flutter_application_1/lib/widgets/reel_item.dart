// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../screens/posts/comments_screen.dart';
import '../screens/profile/other_user_profile_screen.dart';
import 'safe_elements.dart';

bool globalIsMuted = false;

class ReelItem extends StatefulWidget {
  final Map<String, dynamic> reel;
  final String reelId;
  final bool isCurrentPage;

  const ReelItem({
    super.key,
    required this.reel,
    required this.reelId,
    this.isCurrentPage = true,
  });

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  late CachedVideoPlayerPlus _player;
  bool _isInitialized = false;
  bool _isLiked = false;
  bool _isSaved = false;
  bool _isFollowing = false;
  bool _isLoadingFollow = true;
  int _likeCount = 0;
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  bool _hasError = false;
  bool _showBigHeart = false;

  @override
  void initState() {
    super.initState();
    _syncData();
    _initializePlayer();
    _checkFollowStatus();
  }

  // 🌟 మ్యాజిక్: పెర్ఫార్మన్స్ బూస్ట్ & ఆడియో బగ్ ఫిక్స్
  @override
  void didUpdateWidget(ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isInitialized) {
      if (widget.isCurrentPage) {
        _player.controller.play();
        // 🌟 పేజీ లోకి రాగానే గ్లోబల్ సెట్టింగ్ బట్టి వాల్యూమ్ సెట్ అవుతుంది
        _player.controller.setVolume(globalIsMuted ? 0.0 : 1.0);
      } else {
        _player.controller.pause();
        // 🌟 పేజీ దాటి కిందకు వెళ్ళగానే పూర్తిగా సైలెంట్ అయిపోతుంది
        _player.controller.setVolume(0.0);
        _player.controller.seekTo(Duration.zero);
      }
    }
  }

  void _syncData() {
    List likes = widget.reel['likes'] ?? [];
    List savedBy = widget.reel['savedBy'] ?? [];
    _isLiked = likes.contains(currentUid);
    _isSaved = savedBy.contains(currentUid);
    _likeCount = likes.length;
  }

  void _checkFollowStatus() async {
    String ownerId = widget.reel['ownerId'] ?? "";
    if (ownerId == currentUid) {
      if (mounted) setState(() => _isLoadingFollow = false);
      return;
    }

    try {
      var myDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      if (myDoc.exists) {
        List followingList = myDoc.data()?['following'] ?? [];
        if (mounted) {
          setState(() {
            _isFollowing = followingList.contains(ownerId);
            _isLoadingFollow = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingFollow = false);
      debugPrint("Follow Check Error: $e");
    }
  }

  void _initializePlayer() {
    String videoUrl = "";
    if (widget.reel['postData'] != null &&
        widget.reel['postData'] is List &&
        widget.reel['postData'].isNotEmpty) {
      videoUrl = widget.reel['postData'][0].toString();
    } else {
      videoUrl = (widget.reel['storyUrl'] ?? widget.reel['videoUrl'] ?? "")
          .toString();
    }

    if (videoUrl.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    _player = CachedVideoPlayerPlus.networkUrl(Uri.parse(videoUrl));
    _player.initialize().then(
      (_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _hasError = false;
          });
          _player.controller.setLooping(true);
          _player.controller.setVolume(globalIsMuted ? 0.0 : 1.0);

          if (widget.isCurrentPage) {
            _player.controller.play();
          }
        }
      },
      onError: (e) {
        if (mounted) setState(() => _hasError = true);
      },
    );
  }

  void _toggleMute() {
    if (!_isInitialized) return;
    setState(() {
      globalIsMuted = !globalIsMuted;
      _player.controller.setVolume(globalIsMuted ? 0.0 : 1.0);
    });
  }

  void _toggleLike() async {
    setState(() {
      _isLiked = !_isLiked;
      _isLiked ? _likeCount++ : _likeCount--;
    });
    var ref = FirebaseFirestore.instance.collection('posts').doc(widget.reelId);
    if (_isLiked) {
      await ref.update({
        'likes': FieldValue.arrayUnion([currentUid]),
      });
    } else {
      await ref.update({
        'likes': FieldValue.arrayRemove([currentUid]),
      });
    }
  }

  void _handleDoubleTap() {
    _toggleLike();
    setState(() {
      _showBigHeart = true;
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showBigHeart = false);
    });
  }

  void _toggleSave() async {
    setState(() => _isSaved = !_isSaved);
    var ref = FirebaseFirestore.instance.collection('posts').doc(widget.reelId);
    if (_isSaved) {
      await ref.update({
        'savedBy': FieldValue.arrayUnion([currentUid]),
      });
    } else {
      await ref.update({
        'savedBy': FieldValue.arrayRemove([currentUid]),
      });
    }
  }

  void _toggleFollow() async {
    String ownerId = widget.reel['ownerId'];
    if (ownerId == currentUid) return;
    setState(() => _isFollowing = !_isFollowing);
    try {
      var myRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid);
      var ownerRef = FirebaseFirestore.instance
          .collection('users')
          .doc(ownerId);
      if (_isFollowing) {
        await myRef.update({
          'following': FieldValue.arrayUnion([ownerId]),
        });
        await ownerRef.update({
          'followers': FieldValue.arrayUnion([currentUid]),
        });
      } else {
        await myRef.update({
          'following': FieldValue.arrayRemove([ownerId]),
        });
        await ownerRef.update({
          'followers': FieldValue.arrayRemove([currentUid]),
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isFollowing = !_isFollowing);
    }
  }

  void _sendReelToUser(String receiverId, String receiverName) async {
    String url =
        (widget.reel['postData'] is List && widget.reel['postData'].isNotEmpty)
        ? widget.reel['postData'][0]
        : (widget.reel['storyUrl'] ?? "");

    String roomId = currentUid.hashCode <= receiverId.hashCode
        ? "${currentUid}_$receiverId"
        : "${receiverId}_$currentUid";

    var timestamp = FieldValue.serverTimestamp();

    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .add({
          'senderId': currentUid,
          'receiverId': receiverId,
          'text': "Sent a Reel",
          'type': 'shared_reel',
          'mediaUrl': url,
          'sharedPostId': widget.reelId,
          'ownerName': widget.reel['username'] ?? 'User',
          'isRead': false,
          'timestamp': timestamp,
          'isEdited': false,
          'isDeleted': false,
          'deletedBy': [],
        });

    await FirebaseFirestore.instance.collection('chatRooms').doc(roomId).set({
      'users': [currentUid, receiverId],
      'lastMessage': "🎬 Sent a Reel",
      'timestamp': timestamp,
      'unread_$receiverId': FieldValue.increment(1),
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Sent to $receiverName ✅"),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showShareSheet() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(15),
              child: Text(
                "Share to...",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            Expanded(
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUid)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  List following =
                      (snapshot.data!.data()
                          as Map<String, dynamic>)['following'] ??
                      [];

                  if (following.isEmpty) {
                    return const Center(
                      child: Text(
                        "Follow someone to share with them!",
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: following.length,
                    itemBuilder: (context, index) {
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(following[index])
                            .get(),
                        builder: (context, userSnap) {
                          if (!userSnap.hasData || !userSnap.data!.exists)
                            return const SizedBox();
                          var userData =
                              userSnap.data!.data() as Map<String, dynamic>;

                          return ListTile(
                            leading: SafeProfilePic(
                              base64String: userData['profilePic'],
                              radius: 20,
                              fallbackText: userData['username'][0],
                            ),
                            title: Text(
                              userData['username'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF007AFF),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                _sendReelToUser(
                                  following[index],
                                  userData['username'],
                                );
                              },
                              child: const Text(
                                "Send",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(),

            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.share, color: Colors.white),
              ),
              title: const Text(
                "Share via External Apps",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context);
                String url =
                    (widget.reel['postData'] is List &&
                        widget.reel['postData'].isNotEmpty)
                    ? widget.reel['postData'][0]
                    : (widget.reel['storyUrl'] ?? "");
                SharePlus.instance.share(
                  ShareParams(text: "Check out this reel on MyBanjara: $url"),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_isInitialized) _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isOwner = widget.reel['ownerId'] == currentUid;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_hasError)
          const Center(
            child: Icon(Icons.broken_image, color: Colors.grey, size: 50),
          )
        else if (_isInitialized)
          GestureDetector(
            onTap: () {
              if (!_isInitialized) return;
              _player.controller.value.isPlaying
                  ? _player.controller.pause()
                  : _player.controller.play();
            },
            onDoubleTap: _handleDoubleTap,
            child: Center(
              child: AspectRatio(
                aspectRatio: _player.controller.value.aspectRatio,
                child: VideoPlayer(_player.controller),
              ),
            ),
          )
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),

        if (_showBigHeart)
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.5, end: 1.2),
              duration: const Duration(milliseconds: 300),
              curve: Curves.elasticOut,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Icon(
                    Icons.favorite,
                    color: Colors.red.withValues(alpha: 0.5),
                    size: 100,
                  ),
                );
              },
            ),
          ),

        Positioned(
          bottom: 25,
          left: 15,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OtherUserProfileScreen(
                          userId: widget.reel['ownerId'],
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        SafeProfilePic(
                          base64String: widget.reel['profilePic'],
                          radius: 18,
                          fallbackText: (widget.reel['username'] ?? "U")[0],
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.reel['username'] ?? "User",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 2),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (!isOwner && !_isLoadingFollow)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleFollow,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _isFollowing
                              ? Colors.white24
                              : Colors.transparent,
                          border: Border.all(color: Colors.white, width: 1.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _isFollowing ? "Following" : "Follow",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if ((widget.reel['caption'] ?? "").toString().isNotEmpty)
                Text(
                  widget.reel['caption'] ?? "",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                  ),
                ),
            ],
          ),
        ),

        Positioned(
          right: 10,
          bottom: 30,
          child: Column(
            children: [
              IconButton(
                icon: Icon(
                  globalIsMuted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: _toggleMute,
              ),
              const SizedBox(height: 10),
              Column(
                children: [
                  IconButton(
                    icon: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? Colors.red : Colors.white,
                      size: 35,
                    ),
                    onPressed: _toggleLike,
                  ),
                  Text(
                    "$_likeCount",
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 15),
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
                      postId: widget.reelId,
                      postOwnerId: widget.reel['ownerId'],
                      isReel: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              IconButton(
                icon: const Icon(
                  Icons.share_outlined,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: _showShareSheet,
              ),
              const SizedBox(height: 15),
              IconButton(
                icon: Icon(
                  _isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: _toggleSave,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
