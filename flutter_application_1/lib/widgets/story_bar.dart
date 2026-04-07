// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:marquee/marquee.dart';

import 'safe_elements.dart';
import '../utils/constants.dart';
import '../services/upload_manager.dart';
import '../screens/story/story_view_screen.dart';

class StoryBar extends StatefulWidget {
  const StoryBar({super.key});

  @override
  State<StoryBar> createState() => _StoryBarState();
}

class _StoryBarState extends State<StoryBar> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  Map<String, dynamic>? myUserData;

  @override
  void initState() {
    super.initState();
    _fetchMyData();
  }

  void _fetchMyData() async {
    var doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .get();
    if (doc.exists && mounted) setState(() => myUserData = doc.data());
  }

  void _showStoryPicker() {
    if (myUserData == null) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(15),
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
              onTap: () {
                Navigator.pop(ctx);
                _uploadStory(false);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.video_collection,
                color: Color(0xFF833AB4),
              ),
              title: const Text("Video Story"),
              onTap: () {
                Navigator.pop(ctx);
                _uploadStory(true);
              },
            ),
          ],
        ),
      ),
    );
  }

  // 🌟 THE FIX: కంప్రెషన్ తో అప్‌డేట్ చేసిన ఫంక్షన్
  Future<void> _uploadStory(bool isVideo) async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = isVideo
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 100,
          );

    if (file != null && myUserData != null) {
      UploadManager().isUploading.value = true;
      try {
        UploadManager().uploadStatus.value = "Compressing... 🗜️";
        File finalFile = File(file.path);

        if (isVideo) {
          finalFile = await UploadManager().compressVideo(finalFile);
        } else {
          finalFile = await UploadManager().compressImage(finalFile);
        }

        String storyId = const Uuid().v4();
        Reference ref = FirebaseStorage.instance
            .ref()
            .child('stories')
            .child(currentUid)
            .child(storyId);

        UploadTask uploadTask = ref.putFile(finalFile);
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          UploadManager().uploadProgress.value =
              snapshot.bytesTransferred / snapshot.totalBytes;
          UploadManager().uploadStatus.value =
              "Uploading Story... ☁️ ${((snapshot.bytesTransferred / snapshot.totalBytes) * 100).toStringAsFixed(0)}%";
        });

        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();
        DateTime expiryTime = DateTime.now().add(const Duration(hours: 24));

        UploadManager().uploadStatus.value = "Finishing up... ✍️";

        await FirebaseFirestore.instance.collection('stories').add({
          "uid": currentUid,
          "ownerId": currentUid,
          "username": myUserData!['username'] ?? "User",
          "profilePic": myUserData!['profilePic'] ?? "",
          "storyUrl": downloadUrl,
          "type": isVideo ? "video" : "image",
          "timestamp": FieldValue.serverTimestamp(),
          "expiresAt": Timestamp.fromDate(expiryTime),
          "likes": [],
          "viewers": [],
        });

        UploadManager().uploadStatus.value = "Success! 🎉";
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        debugPrint("Error: $e");
        UploadManager().uploadStatus.value = "❌ Error";
      } finally {
        UploadManager().isUploading.value = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 115,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('stories')
            .where('expiresAt', isGreaterThan: Timestamp.now())
            .orderBy('expiresAt')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();

          // 🌟 WHATSAPP LOGIC: గ్రూపింగ్, చూడనివి ముందు, చూసినవి వెనకాల
          Map<String, List<DocumentSnapshot>> userStoriesMap = {};
          for (var doc in snapshot.data!.docs) {
            String uid = doc['uid'];
            if (!userStoriesMap.containsKey(uid)) userStoriesMap[uid] = [];
            userStoriesMap[uid]!.add(doc);
          }

          List<Map<String, dynamic>> unseenUsers = [];
          List<Map<String, dynamic>> seenUsers = [];

          userStoriesMap.forEach((uid, docs) {
            bool hasUnseen = docs.any(
              (doc) => !(doc['viewers'] as List).contains(currentUid),
            );
            var data = docs.first.data() as Map<String, dynamic>;
            var userData = {
              'uid': uid,
              'username': data['username'] ?? 'User',
              'profilePic': data['profilePic'] ?? '',
              'hasUnseen': hasUnseen,
            };
            if (uid == currentUid) {
              // Your story is handled at index 0
            } else if (hasUnseen) {
              unseenUsers.add(userData);
            } else {
              seenUsers.add(userData);
            }
          });

          List<Map<String, dynamic>> finalUsersList = [
            ...unseenUsers,
            ...seenUsers,
          ];
          bool hasMyStory = userStoriesMap.containsKey(currentUid);
          bool hasMyStoryUnseen = hasMyStory
              ? userStoriesMap[currentUid]!.any(
                  (doc) => !(doc['viewers'] as List).contains(currentUid),
                )
              : false;

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            itemCount: finalUsersList.length + 1,
            itemBuilder: (context, index) {
              // 🌟 ITEM 0: YOUR STORY 🌟
              if (index == 0) {
                return GestureDetector(
                  onTap: hasMyStory
                      ? () {
                          // మన స్టోరీస్ మాత్రమే చూపిస్తాం
                          var myStoryList = [
                            {
                              'uid': currentUid,
                              'username': myUserData?['username'],
                              'profilePic': myUserData?['profilePic'],
                            },
                          ];
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StoryViewScreen(
                                usersWithStories: myStoryList,
                                initialUserIndex: 0,
                              ),
                            ),
                          );
                        }
                      : _showStoryPicker,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: hasMyStory
                                    ? (hasMyStoryUnseen ? brandGradient : null)
                                    : null,
                                border: hasMyStory && !hasMyStoryUnseen
                                    ? Border.all(color: Colors.grey, width: 2)
                                    : (hasMyStory
                                          ? null
                                          : Border.all(
                                              color: Colors.grey,
                                              width: 1,
                                            )),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                                child: SafeProfilePic(
                                  base64String: myUserData?['profilePic'] ?? '',
                                  radius: 26,
                                  fallbackText:
                                      myUserData != null &&
                                          myUserData!['username']
                                              .toString()
                                              .isNotEmpty
                                      ? myUserData!['username'][0]
                                      : "Y",
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: _showStoryPicker,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? Colors.black : Colors.white,
                                    width: 2,
                                  ),
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
                        const SizedBox(height: 5),
                        SizedBox(
                          width: 70,
                          height: 15,
                          child: Align(
                            alignment: Alignment.center,
                            child: Text(
                              "Your Story",
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // 🌟 ITEM > 0: OTHER USERS (WhatsApp Auto Next Jump) 🌟
              var user = finalUsersList[index - 1];

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoryViewScreen(
                        usersWithStories: finalUsersList,
                        initialUserIndex: index - 1,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: user['hasUnseen'] ? brandGradient : null,
                          border: user['hasUnseen']
                              ? null
                              : Border.all(color: Colors.grey, width: 2),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? Colors.black : Colors.white,
                          ),
                          child: SafeProfilePic(
                            base64String: user['profilePic'],
                            radius: 26,
                            fallbackText: user['username'].isNotEmpty
                                ? user['username'][0].toUpperCase()
                                : "U",
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      SizedBox(
                        width: 70,
                        height: 15,
                        child: user['username'].length > 8
                            ? Marquee(
                                text: "${user['username']}   ",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                                scrollAxis: Axis.horizontal,
                                blankSpace: 20.0,
                                velocity: 20.0,
                              )
                            : Align(
                                alignment: Alignment.center,
                                child: Text(
                                  user['username'],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
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
    );
  }
}
