// ignore_for_file: unused_local_variable, curly_braces_in_flow_control_structures

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart'; // 🌟 Ensure this is in pubspec.yaml

import 'safe_elements.dart';
import '../screens/comments_screen.dart';

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
    Map likes = widget.post['likes'] ?? {};
    isLiked = likes[currentUid] == true;
    likeCount = likes.values.where((val) => val == true).length;

    List savedBy = widget.post['savedBy'] ?? [];
    isSaved = savedBy.contains(currentUid);
  }

  // 1. EXTERNAL SHARE
  void _shareExternally() async {
    try {
      String base64String = widget.post['postData'] ?? "";
      if (base64String.isEmpty) return;

      final bytes = base64Decode(base64String);
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/shared_post.png').create();
      await file.writeAsBytes(bytes);

      // ignore: deprecated_member_use
      await Share.shareXFiles([
        XFile(file.path),
      ], text: widget.post['caption'] ?? "Check this out!");
    } catch (e) {
      debugPrint("Share Error: $e");
    }
  }

  // 2. INTERNAL SEND LOGIC
  void _sendPostInternally(String receiverId) async {
    try {
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': currentUid,
        'receiverId': receiverId,
        'postId': widget.post['postId'],
        'type': 'post_share',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Sent to friend! ✅")));
      }
    } catch (e) {
      debugPrint("Internal Share Error: $e");
    }
  }

  // 3. 🌟 SHOW SHARE MENU (Internal + External)
  void _showShareMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(15.0),
              child: Text(
                "Share Post",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.apps, color: Colors.white),
              ),
              title: const Text("Share to External Apps"),
              onTap: () {
                Navigator.pop(context);
                _shareExternally();
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Text(
                "Recent Users",
                style: TextStyle(color: Colors.grey, fontSize: 12),
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
                      return ListTile(
                        leading: SafeProfilePic(
                          base64String: user['profilePic'],
                          radius: 18,
                          fallbackText: user['username']?[0] ?? "U",
                        ),
                        title: Text(user['username'] ?? "User"),
                        trailing: TextButton(
                          onPressed: () => _sendPostInternally(users[index].id),
                          child: const Text("Send"),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleLike() async {
    setState(() {
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
    });
    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post['postId'])
        .set({
          'likes': {currentUid: isLiked},
        }, SetOptions(merge: true));

    if (isLiked && currentUid != widget.post['ownerId']) {
      await FirebaseFirestore.instance.collection('notifications').add({
        'receiverId': widget.post['ownerId'],
        'senderName': FirebaseAuth.instance.currentUser!.email!.split('@')[0],
        'type': 'like',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String timeStr = widget.post['timestamp'] != null
        ? timeago.format((widget.post['timestamp'] as Timestamp).toDate())
        : "Just now";
    int commentCount = widget.post['commentCount'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: SafeProfilePic(
              base64String: widget.post['postData'],
              radius: 20,
              fallbackText: widget.post['username'] != null
                  ? widget.post['username'][0]
                  : "U",
            ),
            title: Text(
              widget.post['username'] ?? "User",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              timeStr,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          SafeImage(base64String: widget.post['postData']),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : Colors.black,
                ),
                onPressed: _handleLike,
              ),
              IconButton(
                icon: const Icon(Icons.comment_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CommentsScreen(postId: widget.post['postId']),
                  ),
                ),
              ),
              // 🌟 FIXED: కనెక్ట్ చేయబడిన షేర్ మెనూ
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: _showShareMenu,
              ),
              const Spacer(),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Text(
              "$likeCount likes",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          if (widget.post['caption'] != null &&
              widget.post['caption'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: Text(
                "${widget.post['username']} ${widget.post['caption']}",
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
