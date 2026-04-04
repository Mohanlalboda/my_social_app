// ignore_for_file: use_build_context_synchronously
// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../../widgets/safe_elements.dart';

class CommentsScreen extends StatefulWidget {
  final String postId;
  final String postOwnerId;
  final String mediaUrl; // 🌟 పోస్ట్ థంబ్‌నెయిల్ కోసం
  final bool isReel;

  const CommentsScreen({
    super.key,
    required this.postId,
    required this.postOwnerId,
    this.mediaUrl = "",
    this.isReel = false,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _isPosting = false;
  final String currentUserUid = FirebaseAuth.instance.currentUser!.uid;

  // 🌟 మ్యాజిక్ 2: కామెంట్ పెట్టగానే నోటిఫికేషన్ పంపడం (Updated Path)
  // 🌟 మ్యాజిక్ 2: కామెంట్ పెట్టగానే నోటిఫికేషన్ పంపడం (Fixed: isRead added)
  void _postComment() async {
    String text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);

    try {
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserUid)
          .get();
      String username = userDoc.data()?['username'] ?? "User";
      String profilePic = userDoc.data()?['profilePic'] ?? "";

      String commentId = const Uuid().v4();

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId)
          .set({
            'commentId': commentId,
            'uid': currentUserUid,
            'username': username,
            'profilePic': profilePic,
            'text': text,
            'timestamp': FieldValue.serverTimestamp(),
          });

      if (widget.postOwnerId != currentUserUid) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.postOwnerId)
            .collection('notifications')
            .add({
              'senderId': currentUserUid,
              'senderName': username,
              'senderPic': profilePic,
              'type': 'comment',
              'postId': widget.postId,
              'mediaUrl': widget.mediaUrl,
              'text': text,
              'isRead': false, // 🌟 ఫిక్స్: ఇది మర్చిపోయాం!
              'timestamp': FieldValue.serverTimestamp(),
            });
      }

      _commentController.clear();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error posting comment: $e")));
    }

    setState(() => _isPosting = false);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDark ? Colors.white : Colors.black;
    Color bgColor = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 1,
        title: Text(
          "Comments",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
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
                if (snapshot.hasError)
                  return const Center(child: Text("Something went wrong"));
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                var comments = snapshot.data!.docs;

                if (comments.isEmpty) {
                  return Center(
                    child: Text(
                      "No comments yet.\nBe the first to comment! 💬",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    var data = comments[index].data() as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SafeProfilePic(
                            base64String: data['profilePic'],
                            radius: 18,
                            fallbackText: (data['username'] ?? "U")[0],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['username'] ?? "User",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  data['text'] ?? "",
                                  style: TextStyle(color: textColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          SafeArea(
            child: Container(
              padding: const EdgeInsets.only(
                left: 16,
                right: 8,
                top: 8,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: "Add a comment...",
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        border: InputBorder.none,
                      ),
                      maxLines: null,
                    ),
                  ),
                  _isPosting
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send, color: Colors.blue),
                          onPressed: _postComment,
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
