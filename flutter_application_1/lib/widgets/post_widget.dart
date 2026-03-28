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
import 'cached_media_widget.dart'; // 🌟 మనం కొత్తగా చేసిన విడ్జెట్ ఇంపోర్ట్
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
  int _currentImageIndex = 0;
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _syncData();
    _markPostAsSeen();
  }

  void _syncData() {
    List likes = widget.post['likes'] is List ? widget.post['likes'] : [];
    isLiked = likes.contains(currentUid);
    likeCount = likes.length;

    List savedBy = widget.post['savedBy'] is List ? widget.post['savedBy'] : [];
    isSaved = savedBy.contains(currentUid);
  }

  void _markPostAsSeen() async {
    List viewedBy = widget.post['viewedBy'] ?? [];
    if (!viewedBy.contains(currentUid)) {
      try {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.post['postId'])
            .set({
              'viewedBy': FieldValue.arrayUnion([currentUid]),
            }, SetOptions(merge: true));
      } catch (e) {}
    }
  }

  // 🌟 లైక్ చేసినప్పుడు నోటిఫికేషన్ పంపే మ్యాజిక్
  void _handleLike() async {
    setState(() {
      isLiked = !isLiked;
      isLiked ? likeCount++ : likeCount--;
    });

    try {
      var ref = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post['postId']);

      if (isLiked) {
        await ref.update({
          'likes': FieldValue.arrayUnion([currentUid]),
        });

        String postOwnerId = widget.post['ownerId'];
        // మన పోస్ట్ కి మనం లైక్ కొట్టుకుంటే నోటిఫికేషన్ వద్దు
        if (currentUid != postOwnerId) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'receiverId': postOwnerId,
            'senderId': currentUid,
            'type': 'like',
            'postId': widget.post['postId'],
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
      } else {
        await ref.update({
          'likes': FieldValue.arrayRemove([currentUid]),
        });

        String postOwnerId = widget.post['ownerId'];
        // అన్‌లైక్ చేసినప్పుడు నోటిఫికేషన్ డిలీట్ చేద్దాం
        if (currentUid != postOwnerId) {
          var notifs = await FirebaseFirestore.instance
              .collection('notifications')
              .where('receiverId', isEqualTo: postOwnerId)
              .where('senderId', isEqualTo: currentUid)
              .where('type', isEqualTo: 'like')
              .where('postId', isEqualTo: widget.post['postId'])
              .get();

          for (var doc in notifs.docs) {
            await doc.reference.delete();
          }
        }
      }
    } catch (e) {
      debugPrint("Like Error: $e");
    }
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
      String imageData = "";
      if (widget.post['postData'] is List &&
          (widget.post['postData'] as List).isNotEmpty) {
        imageData = widget.post['postData'][0].toString();
      } else {
        imageData = widget.post['postData']?.toString() ?? "";
      }

      if (imageData.isEmpty) return;

      if (imageData.startsWith('http')) {
        await SharePlus.instance.share(
          ShareParams(
            text:
                "${widget.post['caption'] ?? 'Check out this post on MyBanjara!'}\n\n$imageData",
          ),
        );
      } else {
        if (imageData.contains(',')) imageData = imageData.split(',').last;
        final bytes = base64Decode(imageData.trim());
        final tempDir = await getTemporaryDirectory();
        final file = File(
          '${tempDir.path}/post_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await file.writeAsBytes(bytes);
        if (await file.exists()) {
          final xFile = XFile(file.path, mimeType: 'image/png');
          await SharePlus.instance.share(
            ShareParams(
              text:
                  widget.post['caption'] ?? "Check out this post on MyBanjara!",
              files: [xFile],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("External share error: $e");
    }
  }

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
    } catch (e) {}
  }

  void _showShareMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
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
        );
      },
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
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    String username = widget.post['username'] ?? "User";
    String timeStr = widget.post['timestamp'] != null
        ? timeago.format((widget.post['timestamp'] as Timestamp).toDate())
        : "Just now";
    String postType = widget.post['type'] ?? 'image';

    List<String> images = [];
    if (widget.post['postData'] is List) {
      images = List<String>.from(widget.post['postData']);
    } else if (widget.post['postData'] is String &&
        widget.post['postData'].toString().isNotEmpty) {
      images = [widget.post['postData']];
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 0,
      color: isDark ? Colors.black : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    OtherUserProfileScreen(userId: widget.post['ownerId']),
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

          if (images.isNotEmpty)
            Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                  color: isDark ? Colors.grey[900] : Colors.grey[100],
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: PageView.builder(
                      onPageChanged: (index) =>
                          setState(() => _currentImageIndex = index),
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        String imgData = images[index];
                        return GestureDetector(
                          onDoubleTap: _handleLike,
                          child: imgData.startsWith('http')
                              ? CachedMediaWidget(
                                  mediaUrl: imgData,
                                  type: postType,
                                )
                              : SafeImage(base64String: imgData),
                        );
                      },
                    ),
                  ),
                ),
                if (images.length > 1)
                  Positioned(
                    top: 15,
                    right: 15,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        "${_currentImageIndex + 1}/${images.length}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

          if (images.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (index) => Container(
                  margin: const EdgeInsets.only(top: 8, left: 3, right: 3),
                  width: _currentImageIndex == index ? 8 : 6,
                  height: _currentImageIndex == index ? 8 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? const Color(0xFFFD1D1D)
                        : Colors.grey.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),

          Row(
            children: [
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked
                      ? Colors.red
                      : (isDark ? Colors.white : Colors.black),
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
                        icon: Icon(
                          Icons.comment_outlined,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CommentsScreen(
                              postId: widget.post['postId'],
                              postOwnerId: widget.post['ownerId'],
                            ),
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
                icon: Icon(
                  Icons.send_outlined,
                  color: isDark ? Colors.white : Colors.black,
                ),
                onPressed: _showShareMenu,
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: isDark ? Colors.white : Colors.black,
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
                if (likers.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          UserListScreen(title: "Likes", userIds: likers),
                    ),
                  );
                }
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
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 14,
                ),
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
