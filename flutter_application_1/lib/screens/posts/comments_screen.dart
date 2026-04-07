// ignore_for_file: use_build_context_synchronously, curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../widgets/safe_elements.dart';
import '../../utils/constants.dart';

class CommentsScreen extends StatefulWidget {
  final String postId;
  final String postOwnerId;
  final bool isReel;

  const CommentsScreen({
    super.key,
    required this.postId,
    required this.postOwnerId,
    this.isReel = false,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  bool _isPosting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // 🌟 MAGIC FIX: కామెంట్ యాడ్ చేయడంతో పాటు, పోస్ట్ లోని కౌంటర్ ని పెంచే లాజిక్
  Future<void> _postComment() async {
    String text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);

    try {
      // 1. కరెంట్ యూజర్ డీటెయిల్స్ తెచ్చుకోవడం
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      var userData = userDoc.data() as Map<String, dynamic>;

      String commentId = const Uuid().v4();

      // 🌟 Batch Write వాడితే అన్నీ ఒకేసారి సేఫ్ గా డేటాబేస్ లోకి వెళ్తాయి
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // స్టెప్ A: కామెంట్స్ సబ్-కలెక్షన్ లో కామెంట్ ని సేవ్ చేయడం
      DocumentReference commentRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId);

      batch.set(commentRef, {
        'commentId': commentId,
        'uid': currentUid,
        'username': userData['username'] ?? 'User',
        'profilePic': userData['profilePic'] ?? '',
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 🌟 స్టెప్ B (THE FIX): మెయిన్ పోస్ట్ డాక్యుమెంట్ లో commentCount ని 1 పెంచడం
      DocumentReference postRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId);
      batch.set(postRef, {
        'commentCount': FieldValue.increment(
          1,
        ), // ఇది ఆటోమేటిక్ గా కౌంట్ ని పెంచుతుంది!
      }, SetOptions(merge: true));

      // స్టెప్ C: పోస్ట్ ఓనర్ కి నోటిఫికేషన్ పంపడం (మనం మనకే కామెంట్ పెట్టుకుంటే వద్దు)
      if (widget.postOwnerId != currentUid) {
        DocumentReference notifRef = FirebaseFirestore.instance
            .collection('users')
            .doc(widget.postOwnerId)
            .collection('notifications')
            .doc();

        batch.set(notifRef, {
          'type': 'comment',
          'senderId': currentUid,
          'senderName': userData['username'] ?? 'User',
          'senderPic': userData['profilePic'] ?? '',
          'postId': widget.postId,
          'text': text, // ఏమని కామెంట్ చేశారో కూడా చూపిస్తాం
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // అన్నీ ఒకేసారి ఫైర్‌బేస్ కి పంపడం
      await batch.commit();

      _commentController.clear();
      FocusScope.of(context).unfocus(); // కీబోర్డ్ కిందకి వెళ్ళిపోవడానికి
    } catch (e) {
      debugPrint("Comment Error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to post comment")));
    }

    setState(() => _isPosting = false);
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? brandDarkBackground : Colors.white,
      appBar: AppBar(
        title: const Text(
          "Comments",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: isDark ? brandDarkBackground : Colors.white,
      ),
      body: Column(
        children: [
          // 💬 కామెంట్స్ లిస్ట్ (Real-time)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy(
                    'timestamp',
                    descending: false,
                  ) // పాతవి పైన, కొత్తవి కింద
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 60,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "No comments yet.",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          "Be the first to comment!",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 10, bottom: 20),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var data =
                        snapshot.data!.docs[index].data()
                            as Map<String, dynamic>;
                    String username = data['username'] ?? 'User';
                    DateTime time =
                        (data['timestamp'] as Timestamp?)?.toDate() ??
                        DateTime.now();

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SafeProfilePic(
                            base64String: data['profilePic'] ?? '',
                            radius: 18,
                            fallbackText: username.isNotEmpty
                                ? username[0].toUpperCase()
                                : 'U',
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      username,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      timeago.format(time, locale: 'en_short'),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  data['text'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
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

          // ✍️ కామెంట్ టైప్ చేసే బాక్స్
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.black : Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade800, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: "Add a comment...",
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.grey[900] : Colors.grey[200],
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isPosting
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(
                            Icons.send,
                            color: Color(0xFF00E5FF),
                          ), // 🌟 నియాన్ బ్లూ ఐకాన్
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
