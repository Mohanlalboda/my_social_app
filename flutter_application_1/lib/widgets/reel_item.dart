// ignore_for_file: empty_catches, curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
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
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isLiked = false;
  int _likeCount = 0;
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _syncData();
    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.reel['videoUrl']))
          ..initialize().then((_) {
            if (mounted) {
              setState(() => _isInitialized = true);
              _controller.setLooping(true);
              _controller.play();
            }
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
    var ref = FirebaseFirestore.instance.collection('reels').doc(widget.reelId);
    _isLiked
        ? await ref.update({
            'likes': FieldValue.arrayUnion([currentUid]),
          })
        : await ref.update({
            'likes': FieldValue.arrayRemove([currentUid]),
          });
  }

  // 🌟 యాప్ యూజర్ కి చాట్ లో రీల్ పంపడానికి
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Sent to inbox! ✅")));
    } catch (e) {}
  }

  // 🌟 రీల్స్ షేర్ మెనూ (ఎర్రర్ ఫిక్స్డ్)
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
                // 🌟 FIX: ఇక్కడ ShareParams వాడాము
                SharePlus.instance.share(
                  ShareParams(
                    text:
                        "Check out this Reel on MyBanjara: ${widget.reel['videoUrl']}",
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
      await FirebaseFirestore.instance
          .collection('reels')
          .doc(widget.reelId)
          .delete();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Reel Deleted!")));
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
              await FirebaseFirestore.instance
                  .collection('reels')
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String ownerId = widget.reel['uid'] ?? widget.reel['ownerId'] ?? "";
    bool isMyReel = ownerId == currentUid;

    return Stack(
      fit: StackFit.expand,
      children: [
        _isInitialized
            ? GestureDetector(
                onTap: () => _controller.value.isPlaying
                    ? _controller.pause()
                    : _controller.play(),
                onDoubleTap: _toggleLike,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                ),
              )
            : const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

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
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (widget.reel['caption'] != null &&
                      widget.reel['caption'].toString().isNotEmpty)
                    Text(
                      widget.reel['caption'],
                      style: const TextStyle(color: Colors.white),
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
              Text("$_likeCount", style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 20),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('reels')
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
                          Icons.chat_bubble_outline,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CommentsScreen(
                              postId: widget.reelId,
                              isReel: true,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        "$cCount",
                        style: const TextStyle(color: Colors.white),
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
