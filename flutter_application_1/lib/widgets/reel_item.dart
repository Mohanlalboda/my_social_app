// ignore_for_file: empty_catches, curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../screens/comments_screen.dart';
import 'safe_elements.dart';

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
  int _likeCount = 0;
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  bool _hasError = false; // 🌟 వీడియో లోడ్ అవ్వకపోతే క్రాష్ అవ్వకుండా ఆపడానికి

  @override
  void initState() {
    super.initState();
    _syncData();
    _initializePlayer();
  }

  void _initializePlayer() {
    // 🌟 మ్యాజిక్ ఇక్కడే జరిగింది: లింక్ ని కరెక్ట్ గా లాగుతున్నాం
    String videoUrl = "";

    // 1. మనం అప్‌లోడ్ చేసిన కొత్త పద్ధతి (postData లిస్ట్ లో ఉంటే)
    if (widget.reel['postData'] != null &&
        widget.reel['postData'] is List &&
        widget.reel['postData'].isNotEmpty) {
      videoUrl = widget.reel['postData'][0].toString();
    }
    // 2. లేదా పాత పద్ధతి (storyUrl లేదా videoUrl ఉంటే)
    else if (widget.reel['storyUrl'] != null) {
      videoUrl = widget.reel['storyUrl'].toString();
    } else if (widget.reel['videoUrl'] != null) {
      videoUrl = widget.reel['videoUrl'].toString();
    }

    if (videoUrl.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    _player = CachedVideoPlayerPlus.networkUrl(Uri.parse(videoUrl));
    _player
        .initialize()
        .then((_) {
          if (mounted) {
            setState(() => _isInitialized = true);
            _player.controller.setLooping(true);
            _player.controller.play();
          }
        })
        .catchError((error) {
          // 🌟 వీడియో కరప్ట్ అయితే యాప్ ఫ్రీజ్ అవ్వకుండా ఈ ఎర్రర్ హ్యాండ్లర్ కాపాడుతుంది
          if (mounted) setState(() => _hasError = true);
          debugPrint("Reel Player Error: $error");
        });
  }

  void _syncData() {
    List likes = widget.reel['likes'] ?? [];
    _isLiked = likes.contains(currentUid);
    _likeCount = likes.length;
  }

  void _toggleLike() async {
    setState(() {
      _isLiked = !_isLiked;
      _isLiked ? _likeCount++ : _likeCount--;
    });
    // 🌟 'reels' బదులు 'posts' కలెక్షన్ కి మారుస్తున్నాం ఎందుకంటే మనం ఇప్పుడు రీల్స్ ని పోస్ట్స్ లోనే సేవ్ చేస్తున్నాం
    var ref = FirebaseFirestore.instance.collection('posts').doc(widget.reelId);
    try {
      if (_isLiked) {
        await ref.update({
          'likes': FieldValue.arrayUnion([currentUid]),
        });
      } else {
        await ref.update({
          'likes': FieldValue.arrayRemove([currentUid]),
        });
      }
    } catch (e) {
      debugPrint("Like update error: $e");
    }
  }

  void _sendReelInternally(BuildContext sheetContext, String receiverId) async {
    try {
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': currentUid,
        'receiverId': receiverId,
        'postId': widget.reelId,
        'text': 'Shared a Reel',
        'type': 'reel_share',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      String roomId = currentUid.hashCode <= receiverId.hashCode
          ? "${currentUid}_$receiverId"
          : "${receiverId}_$currentUid";
      await FirebaseFirestore.instance.collection('chatRooms').doc(roomId).set({
        'users': [currentUid, receiverId],
        'lastMessage': "Shared a Reel",
        'timestamp': FieldValue.serverTimestamp(),
        'hasUnread_$receiverId': true,
      }, SetOptions(merge: true));

      if (!sheetContext.mounted) return;
      Navigator.pop(sheetContext);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Sent to inbox! ✅",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint("Share Internal Error: $e");
    }
  }

  void _showShareMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            const Text(
              "Share Reel",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.share, color: Colors.white),
              ),
              title: const Text("Share Link Externally"),
              onTap: () {
                Navigator.pop(ctx);
                String shareUrl = "";
                if (widget.reel['postData'] != null &&
                    widget.reel['postData'].isNotEmpty) {
                  shareUrl = widget.reel['postData'][0];
                }
                SharePlus.instance.share(
                  ShareParams(
                    text: "Check out this Reel on MyBanjara: $shareUrl",
                  ),
                );
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Send to Friends",
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
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
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      var user = users[index].data() as Map<String, dynamic>;
                      String uName = user['username'] ?? "User";
                      return ListTile(
                        leading: SafeProfilePic(
                          base64String: user['profilePic'],
                          radius: 20,
                          fallbackText: uName.isNotEmpty ? uName[0] : "U",
                        ),
                        title: Text(uName),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () =>
                              _sendReelInternally(ctx, users[index].id),
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
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Reel?"),
        content: const Text("Do you really want to delete this reel?"),
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
    if (confirm == true) {
      // 🌟 ఇక్కడ కూడా 'posts' కలెక్షన్ కి మార్చాం
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.reelId)
          .delete();
      if (mounted) {
        Navigator.pop(context); // డిలీట్ అవ్వగానే వెనక్కి వెళ్ళిపోతుంది
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Reel Deleted!")));
      }
    }
  }

  void _editReel() {
    TextEditingController editController = TextEditingController(
      text: widget.reel['caption']?.toString() ?? "",
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Caption"),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
            hintText: "Enter new caption",
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              // 🌟 ఇక్కడ కూడా 'posts'
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.reelId)
                  .update({'caption': editController.text.trim()});
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Caption Updated!")),
                );
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (_isInitialized && !_hasError) {
      _player.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String ownerId = widget.reel['uid'] ?? widget.reel['ownerId'] ?? "";
    bool isMyReel = ownerId == currentUid;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_hasError)
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, color: Colors.grey, size: 60),
                SizedBox(height: 10),
                Text(
                  "Video unavailable or corrupted.",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          )
        else if (_isInitialized)
          GestureDetector(
            onTap: () => _player.controller.value.isPlaying
                ? _player.controller.pause()
                : _player.controller.play(),
            onDoubleTap: _toggleLike,
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
          bottom: 20,
          left: 15,
          child: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(ownerId)
                .get(),
            builder: (context, snapshot) {
              String username = "User";
              String profilePic = "";
              if (snapshot.hasData && snapshot.data!.exists) {
                var userData = snapshot.data!.data() as Map<String, dynamic>;
                username = userData['username'] ?? "User";
                profilePic = userData['profilePic'] ?? "";
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SafeProfilePic(
                        base64String: profilePic,
                        radius: 15,
                        fallbackText: username.isNotEmpty ? username[0] : "U",
                      ),
                      const SizedBox(width: 10),
                      Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 3),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (widget.reel['caption'] != null &&
                      widget.reel['caption'].toString().isNotEmpty)
                    Text(
                      widget.reel['caption'],
                      style: const TextStyle(
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
                      ),
                    ),
                ],
              );
            },
          ),
        ),

        Positioned(
          bottom: 20,
          right: 15,
          child: Column(
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
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts') // 🌟 ఇక్కడ కూడా posts కలెక్షన్
                    .doc(widget.reelId)
                    .collection('comments')
                    .snapshots(),
                builder: (context, snapshot) {
                  int cCount = snapshot.hasData
                      ? snapshot.data!.docs.length
                      : 0;
                  return Column(
                    children: [
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
                              postId: widget.reel['postId'] ?? widget.reelId,
                              postOwnerId: ownerId,
                              isReel: true,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        "$cCount",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              IconButton(
                icon: const Icon(
                  Icons.send_outlined,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: _showShareMenu,
              ),
              const SizedBox(height: 20),

              if (isMyReel)
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: Colors.white,
                    size: 30,
                  ),
                  onSelected: (val) {
                    if (val == 'edit') _editReel();
                    if (val == 'delete') _deleteReel();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text("Edit Reel"),
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
          ),
        ),
      ],
    );
  }
}
