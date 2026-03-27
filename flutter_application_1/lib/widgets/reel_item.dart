// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../screens/comments_screen.dart';
import '../screens/other_user_profile_screen.dart';
import 'safe_elements.dart';

bool globalIsMuted = false;

class ReelItem extends StatefulWidget {
  final Map<String, dynamic> reel;
  final String reelId;

  const ReelItem({super.key, required this.reel, required this.reelId});

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  late CachedVideoPlayerPlus _player;
  bool _isInitialized = false;
  bool _isLiked = false;
  bool _isSaved = false;
  bool _isFollowing = false;
  int _likeCount = 0;
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  bool _hasError = false; // 🌟 ఎర్రర్ వస్తే UIలో చూపించడానికి వాడుతున్నాం

  @override
  void initState() {
    super.initState();
    _syncData();
    _initializePlayer();
    _checkFollowStatus();
  }

  void _syncData() {
    List likes = widget.reel['likes'] ?? [];
    List savedBy = widget.reel['savedBy'] ?? [];
    _isLiked = likes.contains(currentUid);
    _isSaved = savedBy.contains(currentUid);
    _likeCount = likes.length;
  }

  // 🌟 FIXED: userId ఎర్రర్ పోయింది
  void _checkFollowStatus() async {
    String ownerId = widget.reel['ownerId'] ?? "";
    if (ownerId == currentUid) return;

    var myDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .get();

    if (myDoc.exists) {
      List following = myDoc.data()?['following'] ?? [];
      if (mounted) setState(() => _isFollowing = following.contains(ownerId));
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
          _player.controller.play();
        }
      },
      onError: (e) {
        // 🌟 FIXED: catchError ఎర్రర్ పోయింది
        if (mounted) setState(() => _hasError = true);
      },
    );
  }

  void _toggleMute() {
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

    var myRef = FirebaseFirestore.instance.collection('users').doc(currentUid);
    var ownerRef = FirebaseFirestore.instance.collection('users').doc(ownerId);

    setState(() => _isFollowing = !_isFollowing);

    try {
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
      debugPrint("Follow Error: $e");
    }
  }

  void _sendInternalShare(String friendId) async {
    String roomId = currentUid.hashCode <= friendId.hashCode
        ? "${currentUid}_$friendId"
        : "${friendId}_$currentUid";

    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .add({
          'senderId': currentUid,
          'receiverId': friendId,
          'text': 'Shared a Reel 🎬',
          'mediaUrl': widget.reel['postData'][0],
          'type': 'reel_share',
          'postId': widget.reelId,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });

    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Reel sent successfully! ✅")));
  }

  void _showShareSheet() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
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
              padding: EdgeInsets.all(15.0),
              child: Text(
                "Share Reel",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.share, color: Colors.white),
              ),
              title: const Text("Share to External Apps"),
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
            const Divider(),
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 15),
                child: Text(
                  "Send to Friends",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  var users = snapshot.data!.docs
                      .where((doc) => doc.id != currentUid)
                      .toList();
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      var user = users[index].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: SafeProfilePic(
                          base64String: user['profilePic'],
                          radius: 20,
                          fallbackText: (user['username'] ?? "U")[0],
                        ),
                        title: Text(user['username'] ?? "User"),
                        trailing: ElevatedButton(
                          onPressed: () => _sendInternalShare(users[index].id),
                          child: const Text("Send"),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteReel() async {
    bool confirm =
        await showDialog(
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
          .collection('posts')
          .doc(widget.reelId)
          .delete();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Reel Deleted")));
    }
  }

  void _editCaption() {
    TextEditingController ctrl = TextEditingController(
      text: widget.reel['caption'] ?? "",
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Caption"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: "Write something..."),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.reelId)
                  .update({'caption': ctrl.text.trim()});
              Navigator.pop(ctx);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("Updated!")));
            },
            child: const Text("Save"),
          ),
        ],
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
        // 🌟 FIXED: _hasError ని ఇక్కడ వాడుతున్నాం
        if (_hasError)
          const Center(
            child: Icon(Icons.broken_image, color: Colors.grey, size: 50),
          )
        else if (_isInitialized)
          GestureDetector(
            onTap: () => _player.controller.value.isPlaying
                ? _player.controller.pause()
                : _player.controller.play(),
            child: Center(
              child: AspectRatio(
                aspectRatio: _player.controller.value.aspectRatio,
                child: VideoPlayer(_player.controller),
              ),
            ),
          )
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),

        Positioned(
          top: 60,
          left: 15,
          right: 15,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        OtherUserProfileScreen(userId: widget.reel['ownerId']),
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
                      ),
                    ),
                  ],
                ),
              ),
              if (!isOwner)
                GestureDetector(
                  onTap: _toggleFollow,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _isFollowing ? Colors.transparent : Colors.blue,
                      border: Border.all(
                        color: _isFollowing ? Colors.white : Colors.blue,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _isFollowing ? "Following" : "Follow",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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

              if (isOwner) ...[
                const SizedBox(height: 10),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: Colors.white,
                    size: 30,
                  ),
                  onSelected: (val) =>
                      val == 'edit' ? _editCaption() : _deleteReel(),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 10),
                          Text("Edit"),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 10),
                          Text("Delete", style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        Positioned(
          bottom: 25,
          left: 15,
          right: 80,
          child: Text(
            widget.reel['caption'] ?? "",
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
