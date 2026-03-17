import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../widgets/safe_elements.dart';
import 'comments_screen.dart';
import 'story_screen.dart';
import 'add_post_screen.dart';
import 'other_user_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isUploading = false;
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  Future<void> _uploadStory(Map<String, dynamic> userData) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 15,
      maxWidth: 600,
    );

    if (image != null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isUploading = true;
      });
      try {
        String base64Image = base64Encode(await File(image.path).readAsBytes());
        await FirebaseFirestore.instance.collection('stories').add({
          "uid": currentUid,
          "ownerId": currentUid,
          "username": userData['username'] ?? "User",
          "profilePic": userData['profilePic'] ?? "",
          "storyData": base64Image,
          "timestamp": FieldValue.serverTimestamp(),
        });
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Story Added! 🌟"),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        debugPrint(e.toString());
      } finally {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFD1D1D),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPostScreen()),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var userData =
              userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          List following = userData['following'] ?? [];
          List feedUserIds = List.from(following)..add(currentUid);
          DateTime yesterday = DateTime.now().subtract(
            const Duration(hours: 24),
          );

          return Column(
            children: [
              SizedBox(
                height: 110,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('stories')
                      .where('timestamp', isGreaterThanOrEqualTo: yesterday)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox();
                    }
                    var validStories = snapshot.data!.docs
                        .where((doc) => feedUserIds.contains(doc['ownerId']))
                        .toList();
                    Map<String, Map<String, dynamic>> uniqueStoryUsers = {};
                    for (var doc in validStories) {
                      var data = doc.data() as Map<String, dynamic>;
                      data['storyId'] = doc.id;
                      uniqueStoryUsers[data['ownerId']] = data;
                    }
                    var storyList = uniqueStoryUsers.values.toList();
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: storyList.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return GestureDetector(
                            onTap: () => _uploadStory(userData),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                children: [
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      SafeProfilePic(
                                        base64String: userData['profilePic'],
                                        radius: 32,
                                        fallbackText:
                                            userData['username'] ?? "U",
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.blue,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.add,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    "Your Story",
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        var userStory = storyList[index - 1];
                        List viewers = userStory['viewers'] ?? [];
                        bool isSeen = viewers.contains(currentUid);
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    StoryScreen(user: userStory),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: isSeen
                                        ? null
                                        : const LinearGradient(
                                            colors: [
                                              Colors.purple,
                                              Colors.red,
                                              Colors.orange,
                                            ],
                                          ),
                                    color: isSeen ? Colors.grey.shade400 : null,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                    ),
                                    child: SafeProfilePic(
                                      base64String: userStory['profilePic'],
                                      radius: 28,
                                      fallbackText:
                                          userStory['username'] ?? "U",
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  userStory['username'] ?? "User",
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _isUploading
                    ? const Center(child: CircularProgressIndicator())
                    : StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('posts')
                            .orderBy('timestamp', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          var allPosts = snapshot.data!.docs;

                          // 🌟 1. ఫిల్టర్: ఫాలో అవుతున్న వాళ్ళవి + పబ్లిక్ పోస్ట్స్ మాత్రమే
                          var visiblePosts = allPosts.where((doc) {
                            var data = doc.data() as Map<String, dynamic>;
                            bool isFollowing = feedUserIds.contains(
                              data['ownerId'],
                            );
                            bool isPublic =
                                data['isPublic'] ??
                                true; // పాత పోస్ట్‌లకి డీఫాల్ట్ పబ్లిక్
                            return isFollowing || isPublic;
                          }).toList();

                          // 🌟 2. సార్టింగ్: ఫాలో అయ్యే వాళ్ళవి ఫస్ట్, మిగతా పబ్లిక్ పోస్ట్స్ ఆ తర్వాత
                          // 🌟 2. సార్టింగ్: ఫాలో అయ్యే వాళ్ళవి ఫస్ట్, మిగతా పబ్లిక్ పోస్ట్స్ ఆ తర్వాత
                          visiblePosts.sort((a, b) {
                            var aData = a.data() as Map<String, dynamic>;
                            var bData = b.data() as Map<String, dynamic>;

                            bool aFollowing = feedUserIds.contains(
                              aData['ownerId'],
                            );
                            bool bFollowing = feedUserIds.contains(
                              bData['ownerId'],
                            );

                            if (aFollowing && !bFollowing) {
                              return -1; // ఫాలో అయ్యేవి పైకి
                            }
                            if (!aFollowing && bFollowing) {
                              return 1; // పబ్లిక్ వి కిందకి
                            }

                            // ఇద్దరూ ఫాలోవర్స్ లేదా ఇద్దరూ పబ్లిక్ అయితే టైమ్ ప్రకారం చూపిస్తాం
                            Timestamp aTime =
                                aData['timestamp'] ?? Timestamp.now();
                            Timestamp bTime =
                                bData['timestamp'] ?? Timestamp.now();
                            return bTime.compareTo(aTime);
                          });

                          if (visiblePosts.isEmpty) {
                            return const Center(
                              child: Text("No posts found! 🌎"),
                            );
                          }

                          return ListView.builder(
                            itemCount: visiblePosts.length,
                            itemBuilder: (context, index) {
                              var post =
                                  visiblePosts[index].data()
                                      as Map<String, dynamic>;
                              return PostCard(
                                post: post,
                                postId: visiblePosts[index].id,
                                currentUid: currentUid,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------
// 📸 POST CARD DESIGN (Instagram Style)
// -----------------------------------------------------------------
class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final String postId;
  final String currentUid;

  const PostCard({
    super.key,
    required this.post,
    required this.postId,
    required this.currentUid,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool isLiked = false;
  bool isSaved = false;
  int likeCount = 0;

  @override
  void initState() {
    super.initState();
    _syncData();
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncData();
  }

  void _syncData() {
    var likesData = widget.post['likes'];
    List likes = likesData is List
        ? likesData
        : (likesData is Map ? likesData.keys.toList() : []);
    isLiked = likes.contains(widget.currentUid);
    likeCount = likes.length;

    List savedBy = widget.post['savedBy'] ?? [];
    isSaved = savedBy.contains(widget.currentUid);
  }

  void _toggleLike() async {
    setState(() {
      isLiked = !isLiked;
      if (isLiked) {
        likeCount++;
      } else {
        likeCount--;
      }
    });
    try {
      if (isLiked) {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .update({
              'likes': FieldValue.arrayUnion([widget.currentUid]),
            });
        if (widget.currentUid != widget.post['ownerId']) {
          var userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.currentUid)
              .get();
          await FirebaseFirestore.instance.collection('notifications').add({
            'receiverId': widget.post['ownerId'],
            'senderId': widget.currentUid,
            'senderName': userDoc.data()?['username'] ?? 'User',
            'type': 'like',
            'postId': widget.postId,
            'isRead': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      } else {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .update({
              'likes': FieldValue.arrayRemove([widget.currentUid]),
            });
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _toggleSave() async {
    setState(() {
      isSaved = !isSaved;
    });
    try {
      if (isSaved) {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .update({
              'savedBy': FieldValue.arrayUnion([widget.currentUid]),
            });
      } else {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .update({
              'savedBy': FieldValue.arrayRemove([widget.currentUid]),
            });
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _editCaption() {
    TextEditingController editCtrl = TextEditingController(
      text: widget.post['caption'] ?? '',
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Caption"),
        content: TextField(
          controller: editCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Write a new caption...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .update({'caption': editCtrl.text.trim()});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Caption updated! ✏️")),
              );
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showOptionsDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.currentUid == widget.post['ownerId']) ...[
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blue),
                  title: const Text(
                    "Edit Caption",
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _editCaption();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    "Delete Post",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    FirebaseFirestore.instance
                        .collection('posts')
                        .doc(widget.postId)
                        .delete();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Post deleted! 🗑️")),
                    );
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.report, color: Colors.red),
                  title: const Text(
                    "Report Post",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Thanks for reporting! We will review it. 🛡️",
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String timeStr = widget.post['timestamp'] != null
        ? timeago.format((widget.post['timestamp'] as Timestamp).toDate())
        : "";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      OtherUserProfileScreen(uid: widget.post['ownerId']),
                ),
              );
            },
            child: CircleAvatar(
              backgroundColor: Colors.blueAccent,
              backgroundImage:
                  widget.post['profilePic'] != null &&
                      widget.post['profilePic'].toString().isNotEmpty
                  ? MemoryImage(base64Decode(widget.post['profilePic']))
                  : null,
              child:
                  widget.post['profilePic'] == null ||
                      widget.post['profilePic'].toString().isEmpty
                  ? Text(
                      widget.post['username'][0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    )
                  : null,
            ),
          ),
          title: Text(
            widget.post['username'],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showOptionsDialog,
          ),
        ),
        GestureDetector(
          onDoubleTap: _toggleLike,
          child: SafeImage(base64String: widget.post['postData']),
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? Colors.red : Colors.black,
              ),
              onPressed: _toggleLike,
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommentsScreen(
                          postId: widget.postId,
                          isReel: false,
                        ),
                      ),
                    );
                  },
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .doc(widget.postId)
                      .collection('comments')
                      .snapshots(),
                  builder: (context, snapshot) {
                    int commentCount = snapshot.hasData
                        ? snapshot.data!.docs.length
                        : 0;
                    if (commentCount == 0) {
                      return const SizedBox();
                    }
                    return Text(
                      "$commentCount",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    );
                  },
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              icon: Icon(
                isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: isSaved ? Colors.amber[700] : Colors.black,
                size: 28,
              ),
              onPressed: _toggleSave,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$likeCount likes",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (widget.post['caption'] != null &&
                  widget.post['caption'].toString().isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  widget.post['caption'],
                  style: const TextStyle(fontSize: 14),
                ),
              ],
              Text(
                timeStr,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ],
    );
  }
}
