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
  String currentUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    Map likes = widget.post['likes'] ?? {};
    isLiked = likes[currentUid] == true;
    likeCount = likes.values.where((val) => val == true).length;

    List savedBy = widget.post['savedBy'] ?? [];
    isSaved = savedBy.contains(currentUid);
  }

  // 🌟 SHARE లాజిక్ (దీనివల్లే ఇంపార్ట్ ఎర్రర్స్ పోతాయి)
  // 🌟 SHARE లాజిక్ (లేటెస్ట్ SharePlus పద్ధతిలో)
  void _shareExternally(Map post) async {
    try {
      String base64String = post['postData'] ?? "";
      String caption = post['caption'] ?? "";
      String username = post['username'] ?? "User";

      if (base64String.isEmpty) return;

      // 1. Convert Base64 to Image File
      final bytes = base64Decode(base64String);
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/shared_post.png').create();
      await file.writeAsBytes(bytes);

      // 2. Prepare Share Text
      String shareText = caption.isNotEmpty
          ? "Check out this post by $username: $caption"
          : "Check out this post by $username on My Social App!";

      // 3. 🌟 Share using the standard method
      // ఒకవేళ ఎల్లో లైన్ వచ్చినా పట్టించుకోకండి, ఇది పక్కాగా పనిచేస్తుంది!
      await Share.shareXFiles([XFile(file.path)], text: shareText);
    } catch (e) {
      debugPrint("Share Error: $e");
    }
  }

  void _handleLike() async {
    setState(() {
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
    });

    String postId = widget.post['postId'];
    String postOwnerId = widget.post['ownerId'];

    await FirebaseFirestore.instance.collection('posts').doc(postId).set({
      'likes': {currentUid: isLiked},
    }, SetOptions(merge: true));

    if (isLiked && currentUid != postOwnerId) {
      await FirebaseFirestore.instance.collection('notifications').add({
        'receiverId': postOwnerId,
        'senderName': FirebaseAuth.instance.currentUser!.email!.split('@')[0],
        'type': 'like',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    }
  }

  void _handleSave() async {
    setState(() {
      isSaved = !isSaved;
    });
    String postId = widget.post['postId'];
    if (isSaved) {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'savedBy': FieldValue.arrayUnion([currentUid]),
      });
    } else {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'savedBy': FieldValue.arrayRemove([currentUid]),
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
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
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
                icon: const Icon(Icons.comment_outlined, color: Colors.black),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CommentsScreen(postId: widget.post['postId']),
                  ),
                ),
              ),
              // 🌟 ఇక్కడ షేర్ బటన్ కనెక్ట్ చేశాం
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.black),
                onPressed: () => _shareExternally(widget.post),
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
            child: Text(
              "$likeCount likes",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),

          if (widget.post['caption'] != null &&
              widget.post['caption'].toString().trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black),
                  children: [
                    TextSpan(
                      text: "${widget.post['username']} ",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: widget.post['caption'].toString()),
                  ],
                ),
              ),
            ),

          if (commentCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CommentsScreen(postId: widget.post['postId']),
                  ),
                ),
                child: Text(
                  "View all $commentCount comments",
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
