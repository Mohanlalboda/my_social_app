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
    Map likes = widget.post['likes'] ?? {};
    isLiked = likes[currentUid] == true;
    likeCount = likes.values.where((val) => val == true).length;
    List savedBy = widget.post['savedBy'] ?? [];
    isSaved = savedBy.contains(currentUid);
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

  void _shareExternally() async {
    try {
      String base64String = widget.post['postData'] ?? "";
      if (base64String.isEmpty) return;

      // 1. Base64 క్లీన్ చేయడం (స్పేస్‌లు, న్యూలైన్స్ తీసేయడం)
      base64String = base64String
          .replaceAll('\n', '')
          .replaceAll('\r', '')
          .trim();
      if (base64String.contains(',')) {
        base64String = base64String.split(',').last;
      }

      // 2. క్యాప్షన్ ఖాళీగా ఉంటే డిఫాల్ట్ టెక్స్ట్ సెట్ చేయడం
      String shareText = widget.post['caption'] ?? "";
      if (shareText.trim().isEmpty) {
        shareText = "Check out this post on MyBanjara!";
      }

      // 3. ఇమేజ్ బైట్స్ కన్వర్ట్ చేసి టెంపరరీ ఫైల్ క్రియేట్ చేయడం
      final bytes = base64Decode(base64String);
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/shared_post_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);

      if (await file.exists()) {
        final xFile = XFile(file.path, mimeType: 'image/png');

        // 🌟 LATEST SYNTAX: ఇది మీ వార్నింగ్స్ అన్నింటినీ క్లియర్ చేస్తుంది
        await SharePlus.instance.share(
          ShareParams(
            text: shareText,
            files: [xFile], // ఫైల్స్‌ను లిస్ట్ లాగా పంపాలి
          ),
        );
      }
    } catch (e) {
      debugPrint("🚨 SHARE ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Share failed: $e")));
      }
    }
  }

  // 🌟 FIXED: context ఎర్రర్ రాకుండా జాగ్రత్త పడ్డాం
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

      if (!sheetContext.mounted) {
        return;
      }
      Navigator.pop(sheetContext);

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Sent to friend! ✅")));
    } catch (e) {
      debugPrint("Internal Share Error: $e");
    }
  }

  void _showShareMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
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
                backgroundColor: Colors.green,
                child: Icon(Icons.share, color: Colors.white),
              ),
              title: const Text("Share to WhatsApp / Others"),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _shareExternally();
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Text(
                "Send to Friends",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
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
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _sendPostInternally(
                            bottomSheetContext,
                            users[index].id,
                          ),
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

  void _editPost() {
    TextEditingController editController = TextEditingController(
      text: widget.post['caption'] ?? "",
    );
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Edit Caption"),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.post['postId'])
                  .update({'caption': editController.text.trim()});

              if (!dialogContext.mounted) {
                return;
              }
              Navigator.pop(dialogContext);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _deletePost() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Post"),
        content: const Text(
          "Are you sure you want to delete this post? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.post['postId'])
                  .delete();

              if (!dialogContext.mounted) {
                return;
              }
              Navigator.pop(dialogContext);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showLikesList() {
    List<String> likers = [];
    Map likes = widget.post['likes'] ?? {};
    likes.forEach((key, value) {
      if (value == true) {
        likers.add(key);
      }
    });

    if (likers.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserListScreen(title: "Likes", userIds: likers),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String timeStr = widget.post['timestamp'] != null
        ? timeago.format((widget.post['timestamp'] as Timestamp).toDate())
        : "Just now";
    int commentCount = widget.post['commentCount'] ?? 0;
    bool isMyPost = widget.post['ownerId'] == currentUid;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            onTap: () {
              if (!isMyPost) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        OtherUserProfileScreen(uid: widget.post['ownerId']),
                  ),
                );
              }
            },
            leading: SafeProfilePic(
              base64String:
                  widget.post['profilePic'] ?? widget.post['postData'],
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
            trailing: isMyPost
                ? PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'edit') {
                        _editPost();
                      }
                      if (val == 'delete') {
                        _deletePost();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text("Edit"),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: Colors.red),
                          title: Text(
                            "Delete",
                            style: TextStyle(color: Colors.red),
                          ),
                          contentPadding: EdgeInsets.zero,
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
              onTap: _showLikesList,
              child: Text(
                "$likeCount likes",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),

          if (widget.post['caption'] != null &&
              widget.post['caption'].toString().trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black, fontSize: 14),
                  children: [
                    TextSpan(
                      text: "${widget.post['username']} ",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: widget.post['caption']),
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
