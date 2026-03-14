import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

class CommentsScreen extends StatefulWidget {
  final String postId;
  const CommentsScreen({super.key, required this.postId});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _isPosting = false;

  void _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isPosting = true);

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      String username = FirebaseAuth.instance.currentUser!.email!.split('@')[0];

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
            'uid': uid,
            'username': username,
            'text': _commentController.text.trim(),
            'timestamp': FieldValue.serverTimestamp(),
          });

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update({'commentCount': FieldValue.increment(1)});

      _commentController.clear();

      // 🌟 FIXED: Added mounted check before using context
      if (!mounted) {
        return;
      }
      FocusScope.of(context).unfocus();
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Comments")),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                // 🌟 FIXED: Added curly braces
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var comments = snapshot.data!.docs;
                // 🌟 FIXED: Added curly braces
                if (comments.isEmpty) {
                  return const Center(
                    child: Text("No comments yet. Be the first!"),
                  );
                }

                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    var comment =
                        comments[index].data() as Map<String, dynamic>;
                    String timeStr = comment['timestamp'] != null
                        ? timeago.format(
                            (comment['timestamp'] as Timestamp).toDate(),
                          )
                        : "Just now";

                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(
                        comment['username'] ?? "User",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(comment['text']),
                      trailing: Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 8,
                bottom: 8,
                top: 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: "Add a comment...",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  _isPosting
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : TextButton(
                          onPressed: _postComment,
                          child: const Text(
                            "Post",
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
