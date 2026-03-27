// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use, unused_import

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
import 'story_screen.dart';
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
  int _randomSeed = DateTime.now().millisecondsSinceEpoch;

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
        String? uid = FirebaseAuth.instance.currentUser?.uid;

        if (token != null && uid != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'fcmToken': token,
          }, SetOptions(merge: true));

          debugPrint("✅ SUPER BOSS! FCM Token Updated: $token");
        }
      } else {
        debugPrint("❌ యూజర్ పర్మిషన్ ఇవ్వలేదు బాస్!");
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
        _randomSeed = DateTime.now().millisecondsSinceEpoch;
      });
    }
  }

  Future<void> _uploadStory(Map<String, dynamic> userData, bool isVideo) async {
    final ImagePicker picker = ImagePicker();
    if (isVideo) {
      final XFile? file = await picker.pickVideo(source: ImageSource.gallery);
      if (file != null) {
        if (!mounted) return;
        setState(() => _isUploading = true);
        try {
          String storyId = const Uuid().v4();
          Reference ref = FirebaseStorage.instance
              .ref()
              .child('stories')
              .child(currentUid)
              .child(storyId);
          UploadTask uploadTask = ref.putFile(File(file.path));
          TaskSnapshot snapshot = await uploadTask;
          String downloadUrl = await snapshot.ref.getDownloadURL();

          await FirebaseFirestore.instance.collection('stories').add({
            "uid": currentUid,
            "ownerId": currentUid,
            "username": userData['username'] ?? "User",
            "profilePic": userData['profilePic'] ?? "",
            "storyUrl": downloadUrl,
            "type": "video",
            "timestamp": FieldValue.serverTimestamp(),
            "viewers": [],
          });
        } catch (e) {
          debugPrint("Video Upload Error: $e");
        } finally {
          if (mounted) setState(() => _isUploading = false);
        }
      }
    } else {
      final List<XFile> files = await picker.pickMultiImage(imageQuality: 50);
      if (files.isNotEmpty) {
        if (!mounted) return;
        setState(() => _isUploading = true);
        try {
          for (var file in files) {
            String storyId = const Uuid().v4();
            Reference ref = FirebaseStorage.instance
                .ref()
                .child('stories')
                .child(currentUid)
                .child(storyId);
            UploadTask uploadTask = ref.putFile(File(file.path));
            TaskSnapshot snapshot = await uploadTask;
            String downloadUrl = await snapshot.ref.getDownloadURL();

            await FirebaseFirestore.instance.collection('stories').add({
              "uid": currentUid,
              "ownerId": currentUid,
              "username": userData['username'] ?? "User",
              "profilePic": userData['profilePic'] ?? "",
              "storyUrl": downloadUrl,
              "type": "image",
              "timestamp": FieldValue.serverTimestamp(),
              "viewers": [],
            });
          }
        } catch (e) {
          debugPrint("Photo Upload Error: $e");
        } finally {
          if (mounted) setState(() => _isUploading = false);
        }
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
          String currentUserName = userData['username'] ?? "User";
          List feedUserIds = List.from(userData['following'] ?? [])
            ..add(currentUid);
          DateTime yesterday = DateTime.now().subtract(
            const Duration(hours: 24),
          );

          return Column(
            children: [
              // --- స్టోరీస్ సెక్షన్ ---
              SizedBox(
                height: 125,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('stories')
                      .where('timestamp', isGreaterThanOrEqualTo: yesterday)
                      .limit(20)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    var validStories = snapshot.data!.docs.toList();
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
                      itemBuilder: (builderContext, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: () => _showStoryPicker(userData),
                                  child: Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      SafeProfilePic(
                                        base64String: userData['profilePic'],
                                        radius: 32,
                                        fallbackText: currentUserName.isNotEmpty
                                            ? currentUserName[0]
                                            : "U",
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.black
                                              : Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const CircleAvatar(
                                          backgroundColor: Colors.blue,
                                          radius: 8,
                                          child: Icon(
                                            Icons.add,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                AutoScrollText(
                                  text: "Your Story",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        var userStory = storyList[index - 1];
                        List viewers = userStory['viewers'] ?? [];
                        bool isSeen = viewers.contains(currentUid);
                        String sName = userStory['username'] ?? "User";

                        return GestureDetector(
                          onTap: () async {
                            await FirebaseFirestore.instance
                                .collection('stories')
                                .doc(userStory['storyId'])
                                .update({
                                  'viewers': FieldValue.arrayUnion([
                                    currentUid,
                                  ]),
                                });
                            if (!builderContext.mounted) return;
                            Navigator.push(
                              builderContext,
                              MaterialPageRoute(
                                builder: (_) => StoryScreen(user: userStory),
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
                                        ? const LinearGradient(
                                            colors: [Colors.grey, Colors.grey],
                                          )
                                        : const LinearGradient(
                                            colors: [
                                              Color(0xFF833AB4),
                                              Color(0xFFFD1D1D),
                                              Color(0xFFFCAF45),
                                            ],
                                          ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark
                                          ? Colors.black
                                          : Colors.white,
                                    ),
                                    child: SafeProfilePic(
                                      base64String: userStory['profilePic'],
                                      radius: 28,
                                      fallbackText: sName.isNotEmpty
                                          ? sName[0]
                                          : "U",
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                AutoScrollText(
                                  text: sName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSeen
                                        ? Colors.grey
                                        : (isDark
                                              ? Colors.white
                                              : Colors.black),
                                    fontWeight: isSeen
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                  ),
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

              // --- 🌟 ఫీడ్ సెక్షన్ ---
              Expanded(
                child: Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: _refreshFeed,
                      color: const Color(0xFFFD1D1D),
                      child: StreamBuilder<QuerySnapshot>(
                        // 🌟 మ్యాజిక్ ఇక్కడే జరిగింది!
                        stream: FirebaseFirestore.instance
                            .collection('posts')
                            .where(
                              'type',
                              isEqualTo: 'image',
                            ) // 👈 రీల్స్ హోమ్ ఫీడ్ లోకి రాకుండా ఆపేశాం!
                            .orderBy('timestamp', descending: true)
                            .limit(30)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 50),
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 50,
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Text(
                                    "Error: \n${snapshot.error}",
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            );
                          }

                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          var allDocs = snapshot.data!.docs;
                          var allPosts = allDocs.where((doc) {
                            var data = doc.data() as Map<String, dynamic>;
                            bool isPublic =
                                data['isPublic'] == true ||
                                data['isPublic'] == null;
                            bool isFollowing = feedUserIds.contains(
                              data['ownerId'],
                            );
                            return isPublic || isFollowing;
                          }).toList();

                          allPosts.shuffle(Random(_randomSeed));

                          if (allPosts.isEmpty) {
                            return ListView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.3,
                                ),
                                const Center(
                                  child: Text(
                                    "No posts found. Pull down to refresh. 👇",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

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

class AutoScrollText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const AutoScrollText({super.key, required this.text, required this.style});
  @override
  State<AutoScrollText> createState() => _AutoScrollTextState();
}

class _AutoScrollTextState extends State<AutoScrollText> {
  final ScrollController _scrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    _startScrolling();
  }

  void _startScrolling() async {
    await Future.delayed(const Duration(seconds: 2));
    while (mounted) {
      if (_scrollController.hasClients) {
        double maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll > 0) {
          await _scrollController.animateTo(
            maxScroll,
            duration: const Duration(seconds: 2),
            curve: Curves.linear,
          );
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) break;
          await _scrollController.animateTo(
            0,
            duration: const Duration(seconds: 2),
            curve: Curves.linear,
          );
          await Future.delayed(const Duration(seconds: 1));
        } else
          break;
      } else
        await Future.delayed(const Duration(seconds: 1));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: Text(widget.text, style: widget.style),
      ),
    );
  }
}
