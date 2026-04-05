// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import '../../widgets/safe_elements.dart';
import '../../widgets/post_widget.dart';
import '../story/story_view_screen.dart';
import '../create/add_post_screen.dart';
import '../create/video_trimmer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  Key _refreshKey = UniqueKey();

  final LinearGradient brandGradient = const LinearGradient(
    colors: [
      Color(0xFF833AB4), // Purple
      Color(0xFFFD1D1D), // Pink
      Color(0xFFF56040), // Orange
      Color(0xFFFFDC80), // Yellow
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    updateFCMToken();
    _cleanupOldStories();
  }

  Future<void> migrateVideosToReels() async {
    debugPrint("🚀 డేటా మైగ్రేషన్ స్టార్ట్ అయింది...");
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('type', isEqualTo: 'video')
          .get();

      if (snapshot.docs.isEmpty) return;

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data();
        String postId = doc.id;
        await FirebaseFirestore.instance
            .collection('reels')
            .doc(postId)
            .set(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "పాత రీల్స్ అన్నీ సక్సెస్ ఫుల్ గా మారాయి! 🎬 (ఇప్పుడు కోడ్ తీసేయండి)",
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ మైగ్రేషన్ ఎర్రర్: $e");
    }
  }

  Future<void> _cleanupOldStories() async {
    try {
      DateTime yesterday = DateTime.now().subtract(const Duration(hours: 24));
      var snapshot = await FirebaseFirestore.instance
          .collection('stories')
          .where('uid', isEqualTo: currentUid)
          .where('timestamp', isLessThan: yesterday)
          .get();

      for (var doc in snapshot.docs) {
        String storyUrl = doc.data()['storyUrl'] ?? '';
        if (storyUrl.isNotEmpty && storyUrl.contains('firebase')) {
          try {
            await FirebaseStorage.instance.refFromURL(storyUrl).delete();
          } catch (e) {
            debugPrint("Story media delete error: $e"); // 🌟 FIX 1
          }
        }
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint("Cleanup old stories error: $e"); // 🌟 FIX 2
    }
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
      debugPrint("Update FCM Token error: $e"); // 🌟 FIX 3
    }
  }

  Future<void> _refreshFeed() async {
    await Future.delayed(const Duration(milliseconds: 800));
    _cleanupOldStories();
    if (mounted) {
      setState(() {
        _refreshKey = UniqueKey();
      });
    }
  }

  Future<String?> _askForCaption() async {
    TextEditingController captionCtrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
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
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFD1D1D),
            ),
            onPressed: () => Navigator.pop(ctx, captionCtrl.text.trim()),
            child: const Text("Upload", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _backgroundUploadPhotoStories(
    Map<String, dynamic> userData,
    List<XFile> images,
    String? caption,
  ) async {
    UploadManager().isUploading.value = true;
    UploadManager().uploadProgress.value = 0.0;
    UploadManager().uploadStatus.value = "Compressing Stories...";

    try {
      final tempDir = await getTemporaryDirectory();
      for (int i = 0; i < images.length; i++) {
        UploadManager().uploadStatus.value =
            "Uploading Story ${i + 1} of ${images.length}...";
        final outPath = "${tempDir.path}/story_${const Uuid().v4()}.jpg";
        var comp = await FlutterImageCompress.compressAndGetFile(
          images[i].path,
          outPath,
          quality: 60,
          minWidth: 1080,
          minHeight: 1920,
        );

        File fileToUpload = comp != null
            ? File(comp.path)
            : File(images[i].path);
        String storyId = const Uuid().v4();
        Reference ref = FirebaseStorage.instance
            .ref()
            .child('stories')
            .child(currentUid)
            .child('$storyId.jpg');
        UploadTask uploadTask = ref.putFile(fileToUpload);

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          UploadManager().uploadProgress.value =
              (i + (snapshot.bytesTransferred / snapshot.totalBytes)) /
              images.length;
        });

        await uploadTask;
        String downloadUrl = await ref.getDownloadURL();

        await FirebaseFirestore.instance.collection('stories').add({
          "uid": currentUid,
          "ownerId": currentUid,
          "username": userData['username'] ?? "User",
          "profilePic": userData['profilePic'] ?? "",
          "storyUrl": downloadUrl,
          "type": "image",
          "caption": caption ?? "",
          "timestamp": FieldValue.serverTimestamp(),
          "viewers": [],
        });
      }
      UploadManager().uploadStatus.value = "Done!";
    } catch (e) {
      debugPrint("Background story upload error: $e"); // 🌟 FIX 4
    } finally {
      UploadManager().isUploading.value = false;
    }
  }

  void _showStoryPicker(Map<String, dynamic> userData) {
    final ImagePicker picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => SafeArea(
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
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFFFD1D1D),
              ),
              title: const Text("Photo Story"),
              onTap: () async {
                Navigator.pop(bottomSheetContext);
                final List<XFile> images = await picker.pickMultiImage();
                if (images.isNotEmpty) {
                  String? caption = await _askForCaption();
                  if (caption != null)
                    _backgroundUploadPhotoStories(userData, images, caption);
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.video_collection,
                color: Color(0xFF833AB4),
              ),
              title: const Text("Video Story"),
              onTap: () async {
                Navigator.pop(bottomSheetContext);
                final XFile? video = await picker.pickVideo(
                  source: ImageSource.gallery,
                );
                if (video != null && mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoTrimmerScreen(
                        file: File(video.path),
                        userData: userData,
                      ),
                    ),
                  );
                }
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
          bool seen = (data['viewers'] ?? []).contains(currentUid);
          if (!usersMap.containsKey(uid)) {
            usersMap[uid] = {
              'uid': uid,
              'username': data['username'],
              'profilePic': data['profilePic'],
              'allSeen': seen,
            };
          } else if (!seen) {
            usersMap[uid]!['allSeen'] = false;
          }
        }
        var storyList = usersMap.values.toList()
          ..sort(
            (a, b) =>
                a['allSeen'] == b['allSeen'] ? 0 : (a['allSeen'] ? 1 : -1),
          );

        return SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: storyList.length + 1,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemBuilder: (context, index) {
              if (index == 0) return _buildMyStoryBubble(currentUserData);
              var userData = storyList[index - 1];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoryViewScreen(
                      usersWithStories: storyList,
                      initialUserIndex: index - 1,
                    ),
                  ),
                ),
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
                          gradient: userData['allSeen']
                              ? const LinearGradient(
                                  colors: [Colors.grey, Colors.grey],
                                )
                              : brandGradient,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).scaffoldBackgroundColor,
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
                  backgroundColor: Color(0xFFFD1D1D),
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

              ValueListenableBuilder<bool>(
                valueListenable: UploadManager().isUploading,
                builder: (context, isUploading, child) {
                  if (!isUploading) return const SizedBox.shrink();
                  return ValueListenableBuilder<double>(
                    valueListenable: UploadManager().uploadProgress,
                    builder: (context, progress, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 8,
                        ),
                        color: isDark ? Colors.grey[900] : Colors.grey[100],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ValueListenableBuilder<String>(
                                  valueListenable: UploadManager().uploadStatus,
                                  builder: (context, status, child) => Text(
                                    status,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  "${(progress * 100).toInt()}%",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey[300],
                              color: const Color(0xFFFD1D1D),
                              minHeight: 4,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshFeed,
                  color: const Color(0xFFFD1D1D),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .orderBy('timestamp', descending: true)
                        .limit(30)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const Center(child: CircularProgressIndicator());

                      var allPosts = snapshot.data!.docs.where((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        bool isPublic = data['isPublic'] != false;
                        bool isNotReel = data['type'] != 'video';
                        return (isPublic ||
                                following.contains(data['ownerId'])) &&
                            isNotReel;
                      }).toList();

                      if (allPosts.isEmpty)
                        return const Center(child: Text("No posts found. 👇"));

                      return ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        itemCount: allPosts.length,
                        itemBuilder: (context, index) {
                          var post =
                              allPosts[index].data() as Map<String, dynamic>;
                          post['postId'] = allPosts[index].id;
                          return PostWidget(post: post);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
