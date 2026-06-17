import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart'; // 🌟 THE FIX
import '../../services/firestore_methods.dart';

class ReelCommentsScreen extends StatefulWidget {
  final String reelId;
  const ReelCommentsScreen({super.key, required this.reelId});

  @override
  State<ReelCommentsScreen> createState() => _ReelCommentsScreenState();
}

class _ReelCommentsScreenState extends State<ReelCommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  Map<String, dynamic>? userData;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      var userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (userSnap.exists) {
        setState(() {
          userData = userSnap.data();
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingUser = false);
    }
  }

  void _submitComment() async {
    if (userData == null || _commentController.text.trim().isEmpty) return;
    String res = await FirestoreMethods().postReelComment(
      widget.reelId,
      _commentController.text.trim(),
      FirebaseAuth.instance.currentUser!.uid,
      userData!['username'] ?? 'Anonymous',
      userData!['profilePic'] ?? '',
    );
    if (res == "success") _commentController.clear();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        title: const Text(
          'Reel Comments',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('reels')
            .doc(widget.reelId)
            .collection('comments')
            .orderBy('datePublished', descending: true)
            .snapshots(),
        builder:
            (
              context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                return const Center(
                  child: Text(
                    'No comments yet on this reel. 💬',
                    style: TextStyle(color: Colors.grey),
                  ),
                );

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var comment = snapshot.data!.docs[index].data();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          // 🌟 Image Cache
                          backgroundImage:
                              comment['profilePic'].toString().isNotEmpty
                              ? CachedNetworkImageProvider(
                                  comment['profilePic'],
                                )
                              : const CachedNetworkImageProvider(
                                  'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                                ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(color: textColor),
                                    children: [
                                      TextSpan(
                                        text: comment['name'] ?? 'User',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '  ${comment['text'] ?? ''}',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  comment['datePublished'] != null
                                      ? timeago.format(
                                          (comment['datePublished']
                                                  as Timestamp)
                                              .toDate(),
                                        )
                                      : 'Just now',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: kToolbarHeight,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                // 🌟 Image Cache
                backgroundImage:
                    userData != null &&
                        userData!['profilePic'].toString().isNotEmpty
                    ? CachedNetworkImageProvider(userData!['profilePic'])
                    : const CachedNetworkImageProvider(
                        'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: TextField(
                    controller: _commentController,
                    style: TextStyle(color: textColor),
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              _isLoadingUser
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: _submitComment,
                      child: const Text(
                        'Post',
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
