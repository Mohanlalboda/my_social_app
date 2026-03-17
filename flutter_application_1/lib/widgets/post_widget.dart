// ignore_for_file: curly_braces_in_flow_control_structures, empty_catches

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'safe_elements.dart';
import '../screens/comments_screen.dart';
import '../screens/other_user_profile_screen.dart';
import '../screens/user_list_screen.dart';

class PostWidget extends StatefulWidget {
  final Map<String, dynamic> post;
  const PostWidget({super.key, required this.post});

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  bool isLiked = false;
  bool isSaved = false;
  int likeCount = 0;
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _syncData();
  }

  void _syncData() {
    List likes = widget.post['likes'] is List ? widget.post['likes'] : [];
    isLiked = likes.contains(currentUid);
    likeCount = likes.length;

    List savedBy = widget.post['savedBy'] is List ? widget.post['savedBy'] : [];
    isSaved = savedBy.contains(currentUid);
  }

  void _handleLike() async {
    setState(() {
      isLiked = !isLiked;
      isLiked ? likeCount++ : likeCount--;
    });
    try {
      var ref = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post['postId']);
      isLiked
          ? await ref.update({
              'likes': FieldValue.arrayUnion([currentUid]),
            })
          : await ref.update({
              'likes': FieldValue.arrayRemove([currentUid]),
            });
    } catch (e) {}
  }

  void _handleSave() async {
    setState(() => isSaved = !isSaved);
    try {
      var ref = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post['postId']);
      isSaved
          ? await ref.update({
              'savedBy': FieldValue.arrayUnion([currentUid]),
            })
          : await ref.update({
              'savedBy': FieldValue.arrayRemove([currentUid]),
            });
    } catch (e) {}
  }

  void _shareExternally() async {
    try {
      String base64String = widget.post['postData']?.toString() ?? "";
      if (base64String.isEmpty) return;
      if (base64String.contains(','))
        base64String = base64String.split(',').last;
      final bytes = base64Decode(base64String.trim());
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/post_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      if (await file.exists()) {
        final xFile = XFile(file.path, mimeType: 'image/png');
        await SharePlus.instance.share(
          ShareParams(
            text: widget.post['caption'] ?? "Check out this post on MyBanjara!",
            files: [xFile],
          ),
        );
      }
    } catch (e) {
      debugPrint("External share error: $e");
    }
  }

  // 🌟 యాప్ యూజర్ కి చాట్ లో పోస్ట్ పంపడానికి
  void _sendPostInternally(BuildContext sheetContext, String receiverId) async {
    try {
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': currentUid,
        'receiverId': receiverId,
        'postId': widget.post['postId'],
        'text': 'Shared a post',
        'type': 'post_share',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      String roomId = currentUid.hashCode <= receiverId.hashCode
          ? "${currentUid}_$receiverId"
          : "${receiverId}_$currentUid";

      await FirebaseFirestore.instance.collection('chatRooms').doc(roomId).set({
        'users': [currentUid, receiverId],
        'lastMessage': "Shared a post",
        'timestamp': FieldValue.serverTimestamp(),
        'hasUnread_$receiverId': true,
      }, SetOptions(merge: true));

      if (!sheetContext.mounted) return;
      Navigator.pop(sheetContext);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Sent to inbox! ✅")));
    } catch (e) {
      debugPrint("Internal share error: $e");
    }
  }

  // 🌟 ఇంటర్నల్ & ఎక్స్‌టర్నల్ షేర్ మెనూ
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
              "Share Post",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.share, color: Colors.white),
              ),
              title: const Text("Share to WhatsApp / Others"),
              onTap: () {
                Navigator.pop(ctx);
                _shareExternally();
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
                              _sendPostInternally(ctx, users[index].id),
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

  void _deletePost() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Post?"),
        content: const Text("Are you sure? This cannot be undone."),
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
          .collection('posts')
          .doc(widget.post['postId'])
          .delete();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Post Deleted!")));
    }
  }

  void _editPost() {
    TextEditingController editController = TextEditingController(
      text: widget.post['caption']?.toString() ?? "",
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
                  .collection('posts')
                  .doc(widget.post['postId'])
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
  Widget build(BuildContext context) {
    String username = widget.post['username'] ?? "User";
    String timeStr = widget.post['timestamp'] != null
        ? timeago.format((widget.post['timestamp'] as Timestamp).toDate())
        : "Just now";

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      elevation: 0,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    OtherUserProfileScreen(uid: widget.post['ownerId']),
              ),
            ),
            leading: SafeProfilePic(
              base64String: widget.post['profilePic'],
              radius: 20,
              fallbackText: username.isNotEmpty ? username[0] : "U",
            ),
            title: Text(
              username,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(timeStr, style: const TextStyle(fontSize: 12)),
            trailing: widget.post['ownerId'] == currentUid
                ? PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'edit') _editPost();
                      if (val == 'delete') _deletePost();
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'edit', child: Text("Edit")),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          "Delete",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  )
                : null,
          ),
          GestureDetector(
            onDoubleTap: _handleLike,
            child: SafeImage(base64String: widget.post['postData']),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : Colors.black,
                ),
                onPressed: _handleLike,
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(widget.post['postId'])
                    .collection('comments')
                    .snapshots(),
                builder: (context, snapshot) {
                  int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.comment_outlined),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CommentsScreen(postId: widget.post['postId']),
                          ),
                        ),
                      ),
                      if (count > 0)
                        Text(
                          "$count",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                    ],
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.send_outlined),
                onPressed: _showShareMenu,
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: Colors.black,
                ),
                onPressed: _handleSave,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: GestureDetector(
              onTap: () {
                List<String> likers = List<String>.from(
                  widget.post['likes'] ?? [],
                );
                if (likers.isNotEmpty)
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          UserListScreen(title: "Likes", userIds: likers),
                    ),
                  );
              },
              child: Text(
                "$likeCount likes",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (widget.post['caption'] != null &&
              widget.post['caption'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: Text(
                widget.post['caption'].toString(),
                style: const TextStyle(color: Colors.black, fontSize: 14),
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
