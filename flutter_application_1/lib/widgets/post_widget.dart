import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'safe_elements.dart';

class PostWidget extends StatefulWidget {
  final Map<String, dynamic> post;
  const PostWidget({super.key, required this.post});

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  bool isLikeAnimating = false;
  bool? isSavedLocal;

  void _handleSave() async {
    String postId = widget.post['postId'];
    String currentUid = FirebaseAuth.instance.currentUser!.uid;
    List savedBy = widget.post['savedBy'] ?? [];
    bool isSaved = isSavedLocal ?? savedBy.contains(currentUid);

    setState(() {
      isSavedLocal = !isSaved;
    });

    if (isSaved) {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        "savedBy": FieldValue.arrayRemove([currentUid]),
      });
    } else {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        "savedBy": FieldValue.arrayUnion([currentUid]),
      });

      // 🌟 FIXED: Guards context use after async gap
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Post Saved! 📌")));
    }
  }

  Future<void> _shareExternally(Map<String, dynamic> post) async {
    try {
      String cleanString = post['postData'].replaceAll(RegExp(r'\s+'), '');
      String normalized = base64.normalize(cleanString);
      final bytes = base64Decode(normalized);

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/shared_post.png').create();
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Check out this post on MyBanjara!',
        ),
      );
    } catch (e) {
      debugPrint('Error sharing: $e');
    }
  }

  void _showComments(BuildContext context, String postId) {
    final TextEditingController commentController = TextEditingController();
    final String currentUid = FirebaseAuth.instance.currentUser!.uid;
    final String currentEmail = FirebaseAuth.instance.currentUser!.email!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 15,
            right: 15,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Comments",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const Divider(),
              SizedBox(
                height: 300,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .doc(postId)
                      .collection('comments')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    // 🌟 FIXED: Added curly braces for if block
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var comments = snapshot.data!.docs;
                    return ListView.builder(
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        var c = comments[index].data() as Map<String, dynamic>;
                        String timeStr = c['timestamp'] != null
                            ? timeago.format(
                                (c['timestamp'] as Timestamp).toDate(),
                                locale: 'en_short',
                              )
                            : "";
                        return ListTile(
                          leading: SafeProfilePic(
                            base64String: "",
                            radius: 18,
                            fallbackText: c['username'],
                          ),
                          title: Row(
                            children: [
                              Text(
                                c['username'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                timeStr,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(c['text']),
                        );
                      },
                    );
                  },
                ),
              ),
              TextField(
                controller: commentController,
                decoration: InputDecoration(
                  hintText: "Add a comment...",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send, color: Colors.blue),
                    onPressed: () async {
                      if (commentController.text.isNotEmpty) {
                        await FirebaseFirestore.instance
                            .collection('posts')
                            .doc(postId)
                            .collection('comments')
                            .add({
                              "text": commentController.text.trim(),
                              "username": currentEmail.split('@')[0],
                              "timestamp": FieldValue.serverTimestamp(),
                              "uid": currentUid,
                            });
                        await FirebaseFirestore.instance
                            .collection('posts')
                            .doc(postId)
                            .update({"commentCount": FieldValue.increment(1)});
                        commentController.clear();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _handleLike() async {
    String postId = widget.post['postId'];
    String currentUid = FirebaseAuth.instance.currentUser!.uid;
    bool isLiked =
        (widget.post['likes'] != null &&
        widget.post['likes'][currentUid] == true);

    if (!isLiked) {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        "likes.$currentUid": true,
      });
    } else {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        "likes.$currentUid": FieldValue.delete(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String currentUid = FirebaseAuth.instance.currentUser!.uid;
    bool isLiked =
        (widget.post['likes'] != null &&
        widget.post['likes'][currentUid] == true);
    bool isSaved =
        isSavedLocal ?? (widget.post['savedBy'] ?? []).contains(currentUid);
    int likeCount = (widget.post['likes'] != null)
        ? (widget.post['likes'] as Map).length
        : 0;

    String postTime = widget.post['timestamp'] != null
        ? timeago.format((widget.post['timestamp'] as Timestamp).toDate())
        : "Just now";

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: SafeProfilePic(
              base64String: "",
              radius: 20,
              fallbackText: widget.post['username'],
            ),
            title: Text(
              widget.post['username'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(postTime, style: const TextStyle(fontSize: 10)),
            trailing: widget.post['ownerId'] == currentUid
                ? PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'delete') {
                        await FirebaseFirestore.instance
                            .collection('posts')
                            .doc(widget.post['postId'])
                            .delete();
                      }
                    },
                    itemBuilder: (context) => [
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
            child: SafeImage(
              base64String: widget.post['postData'],
              height: 400,
              width: double.infinity,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.black,
                  ),
                  onPressed: _handleLike,
                ),
                Text("$likeCount"),
                const SizedBox(width: 15),
                IconButton(
                  icon: const Icon(Icons.mode_comment_outlined),
                  onPressed: () =>
                      _showComments(context, widget.post['postId']),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () => _shareExternally(widget.post),
                ),
                IconButton(
                  icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
                  onPressed: _handleSave,
                ),
              ],
            ),
          ),
          // 🌟 కొత్త కోడ్ (Null-safe చెక్)
          if (widget.post['caption'] != null &&
              widget.post['caption'].toString().trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: Text(widget.post['caption'].toString()),
            ),
        ],
      ),
    );
  }
}
