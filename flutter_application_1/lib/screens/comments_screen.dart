import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

class CommentsScreen extends StatefulWidget {
  final String postId;
  final bool isReel;

  const CommentsScreen({super.key, required this.postId, this.isReel = false});

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

      String collectionName = widget.isReel ? 'reels' : 'posts';

      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(widget.postId)
          .collection('comments')
          .add({
            'uid': uid,
            'username': username,
            'text': _commentController.text.trim(),
            'timestamp': FieldValue.serverTimestamp(),
          });

      var docRef = await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(widget.postId)
          .get();

      String ownerId = widget.isReel ? docRef['uid'] : docRef['ownerId'];

      if (ownerId != uid) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'receiverId': ownerId,
          'senderId': uid,
          'senderName': username,
          'type': 'comment',
          'postId': widget.postId,
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      _commentController.clear();
    } catch (e) {
      debugPrint("🚨 Error saving comment: $e");
    }

    setState(() => _isPosting = false);
  }

  @override
  Widget build(BuildContext context) {
    String collectionName = widget.isReel ? 'reels' : 'posts';

    return Scaffold(
      appBar: AppBar(title: const Text("Comments")),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(collectionName)
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var comments = snapshot.data!.docs;
                if (comments.isEmpty) {
                  return const Center(
                    child: Text("No comments yet. Be the first!"),
                  );
                }
                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    var c = comments[index].data() as Map<String, dynamic>;
                    String timeStr = c['timestamp'] != null
                        ? timeago.format((c['timestamp'] as Timestamp).toDate())
                        : "Just now";
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.blueAccent,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.black),
                          children: [
                            TextSpan(
                              text: "${c['username']} ",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(text: c['text']),
                          ],
                        ),
                      ),
                      subtitle: Text(
                        timeStr,
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
