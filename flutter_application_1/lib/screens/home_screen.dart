// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../widgets/safe_elements.dart';
import '../widgets/post_widget.dart';
import 'story_view_screen.dart';
import 'add_post_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  bool _isUploading = false;
  Key _refreshKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    updateFCMToken();
  }

  Future<void> updateFCMToken() async {
    try {
      NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUid)
              .set({'fcmToken': token}, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint("❌ Token Error: $e");
    }
  }

  Future<void> _refreshFeed() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _refreshKey = UniqueKey();
      });
    }
  }

  // 🌟 మ్యాజిక్ ఇక్కడే: స్టోరీ సెలెక్ట్ చేశాక క్యాప్షన్ అడిగే పాప్-అప్
  Future<String?> _askForCaption() async {
    TextEditingController captionCtrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false, // బయట నొక్కితే క్లోజ్ అవ్వదు
      builder: (ctx) => AlertDialog(
        title: const Text("Add Caption"),
        content: TextField(
          controller: captionCtrl,
          decoration: const InputDecoration(
            hintText: "Write a caption for your story...",
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, null), // Cancel నొక్కితే null వెళ్తుంది
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              ctx,
              captionCtrl.text.trim(),
            ), // Upload నొక్కితే టెక్స్ట్ వెళ్తుంది
            child: const Text("Upload Story"),
          ),
        ],
      ),
    );
  }

  // 🌟 STORY UPLOAD LOGIC (With Caption)
  Future<void> _uploadStory(Map<String, dynamic> userData, bool isVideo) async {
    final ImagePicker picker = ImagePicker();

    // 1. ఫైల్ సెలెక్ట్ చేసుకోవడం
    XFile? file;
    if (isVideo) {
      file = await picker.pickVideo(source: ImageSource.gallery);
    } else {
      // స్టోరీకి సింగిల్ ఇమేజ్ బెస్ట్, కాబట్టి pickImage వాడాను (క్వాలిటీ 60)
      file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
      );
    }

    if (file != null) {
      // 2. ఫైల్ వచ్చాక క్యాప్షన్ అడగడం
      String? caption = await _askForCaption();

      // ఒకవేళ యూజర్ Cancel నొక్కితే ఇక్కడే ఆగిపోతుంది
      if (caption == null) return;

      setState(() => _isUploading = true);
      try {
        String storyId = const Uuid().v4();
        Reference ref = FirebaseStorage.instance
            .ref()
            .child('stories')
            .child(currentUid)
            .child('$storyId${isVideo ? ".mp4" : ".jpg"}');

        await ref.putFile(File(file.path));
        String downloadUrl = await ref.getDownloadURL();

        // 3. క్యాప్షన్ తో పాటు డేటాబేస్ లో సేవ్ చేయడం
        await FirebaseFirestore.instance.collection('stories').add({
          "uid": currentUid,
          "ownerId": currentUid,
          "username": userData['username'] ?? "User",
          "profilePic": userData['profilePic'] ?? "",
          "storyUrl": downloadUrl,
          "type": isVideo ? "video" : "image",
          "caption": caption, // 🌟 క్యాప్షన్ ఇక్కడ యాడ్ అవుతుంది
          "timestamp": FieldValue.serverTimestamp(),
          "viewers": [],
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Story Uploaded Successfully! ✅"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint("Upload Error: $e");
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  void _showStoryPicker(Map<String, dynamic> userData) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(15.0),
              child: Text(
                "Add to Story",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text("Photo Story"),
              onTap: () {
                Navigator.pop(context);
                _uploadStory(userData, false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_collection, color: Colors.pink),
              title: const Text("Video Story"),
              onTap: () {
                Navigator.pop(context);
                _uploadStory(userData, true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoriesSection(Map<String, dynamic> currentUserData) {
    DateTime yesterday = DateTime.now().subtract(const Duration(hours: 24));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('stories')
          .where('timestamp', isGreaterThanOrEqualTo: yesterday)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 110);

        Map<String, Map<String, dynamic>> usersMap = {};
        for (var doc in snapshot.data!.docs) {
          var data = doc.data() as Map<String, dynamic>;
          String uid = data['uid'];
          List viewers = data['viewers'] ?? [];
          bool seen = viewers.contains(currentUid);

          if (!usersMap.containsKey(uid)) {
            usersMap[uid] = {
              'uid': uid,
              'username': data['username'],
              'profilePic': data['profilePic'],
              'allSeen': seen,
            };
          } else {
            if (!seen) usersMap[uid]!['allSeen'] = false;
          }
        }

        var storyList = usersMap.values.toList();
        storyList.sort((a, b) {
          if (a['allSeen'] == b['allSeen']) return 0;
          return a['allSeen'] ? 1 : -1;
        });

        return SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: storyList.length + 1,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildMyStoryBubble(currentUserData);
              }

              var userData = storyList[index - 1];
              bool isAllSeen = userData['allSeen'] ?? false;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoryViewScreen(
                        usersWithStories: storyList,
                        initialUserIndex: index - 1,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isAllSeen
                              ? const LinearGradient(
                                  colors: [Colors.grey, Colors.grey],
                                )
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFFf9ce34),
                                    Color(0xFFee2a7b),
                                    Color(0xFF6228d7),
                                  ],
                                ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black,
                          ),
                          child: SafeProfilePic(
                            base64String: userData['profilePic'],
                            radius: 30,
                            fallbackText: userData['username'][0],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 70,
                        child: Text(
                          userData['username'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMyStoryBubble(Map<String, dynamic> userData) {
    return GestureDetector(
      onTap: () => _showStoryPicker(userData),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                SafeProfilePic(
                  base64String: userData['profilePic'],
                  radius: 32,
                  fallbackText: (userData['username'] ?? "U")[0],
                ),
                const CircleAvatar(
                  backgroundColor: Colors.blue,
                  radius: 10,
                  child: Icon(Icons.add, color: Colors.white, size: 14),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text("Your Story", style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFD1D1D),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddPostScreen()),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        key: _refreshKey,
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          var userData =
              userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          List following = List.from(userData['following'] ?? [])
            ..add(currentUid);

          return Column(
            children: [
              _buildStoriesSection(userData),
              const Divider(height: 1),
              Expanded(
                child: Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: _refreshFeed,
                      color: const Color(0xFFFD1D1D),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('posts')
                            .where('type', isEqualTo: 'image')
                            .orderBy('timestamp', descending: true)
                            .limit(30)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData)
                            return const Center(
                              child: CircularProgressIndicator(),
                            );

                          var allPosts = snapshot.data!.docs.where((doc) {
                            var data = doc.data() as Map<String, dynamic>;
                            bool isPublic = data['isPublic'] != false;
                            return isPublic ||
                                following.contains(data['ownerId']);
                          }).toList();

                          if (allPosts.isEmpty)
                            return const Center(
                              child: Text("No posts found. 👇"),
                            );

                          return ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            itemCount: allPosts.length,
                            itemBuilder: (context, index) {
                              var post =
                                  allPosts[index].data()
                                      as Map<String, dynamic>;
                              post['postId'] = allPosts[index].id;
                              return PostWidget(post: post);
                            },
                          );
                        },
                      ),
                    ),
                    if (_isUploading)
                      Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[900] : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 4),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  "Uploading Story...",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
