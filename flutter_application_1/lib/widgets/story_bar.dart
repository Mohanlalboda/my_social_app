// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

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
                _pickStoryAndShowPreview(
                  false,
                ); // 🌟 THE FIX: డైలాగ్ ఓపెన్ అవుతుంది
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
                _pickStoryAndShowPreview(
                  true,
                ); // 🌟 THE FIX: డైలాగ్ ఓపెన్ అవుతుంది
              },
            ),
          ],
        ),
      ),
    );
  }

  // 🌟 1. ఫైల్ సెలెక్ట్ చేసుకొని క్యాప్షన్ డైలాగ్ చూపించడం
  Future<void> _pickStoryAndShowPreview(bool isVideo) async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = isVideo
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 100,
          );

    if (file != null && myUserData != null) {
      File mediaFile = File(file.path);
      TextEditingController captionController = TextEditingController();
      bool isUploadingLocal = false;

      // డైలాగ్ ఓపెన్ చేస్తున్నాం
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: const Text(
                "Add Story",
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: !isVideo
                        ? Image.file(
                            mediaFile,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            height: 200,
                            width: double.infinity,
                            color: Colors.black,
                            child: const Center(
                              child: Icon(
                                Icons.play_circle,
                                size: 50,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: captionController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Write a caption...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.black54,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    maxLines: 2,
                  ),
                  if (isUploadingLocal) ...[
                    const SizedBox(height: 15),
                    const LinearProgressIndicator(color: Colors.blue),
                  ],
                ],
              ),
              actions: [
                if (!isUploadingLocal)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ElevatedButton(
                  onPressed: isUploadingLocal
                      ? null
                      : () async {
                          setDialogState(() => isUploadingLocal = true);
                          String caption = captionController.text.trim();
                          Navigator.pop(
                            ctx,
                          ); // డైలాగ్ క్లోజ్ చేసి అప్‌లోడ్ స్టార్ట్ చేస్తాం
                          await _processAndUpload(mediaFile, isVideo, caption);
                        },
                  child: const Text("Share"),
                ),
              ],
            );
          },
        ),
      );
    }
  }

  // 🌟 బ్యాక్‌గ్రౌండ్‌లో అప్‌లోడ్ జరిగే ఫంక్షన్
  Future<void> _processAndUpload(
    File finalFile,
    bool isVideo,
    String caption,
  ) async {
    UploadManager().isUploading.value = true;
    try {
      UploadManager().uploadStatus.value = "Compressing... 🗜️";

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
        "caption": caption, // 🌟 THE FIX: క్యాప్షన్ సేవ్ చేస్తున్నాం
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

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    // 🌟 THE FIX: మనం ఎవరిని ఫాలో అవుతున్నామో ఆ లిస్ట్
    List followingList = myUserData?['following'] ?? [];

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

          Map<String, List<DocumentSnapshot>> userStoriesMap = {};

          for (var doc in snapshot.data!.docs) {
            String uid = doc['uid'];
            // 🌟 3. THE FIX: మన స్టోరీ లేదా మనం ఫాలో అయ్యే వాళ్ల స్టోరీ అయితేనే చూపిస్తాం
            if (uid == currentUid || followingList.contains(uid)) {
              if (!userStoriesMap.containsKey(uid)) userStoriesMap[uid] = [];
              userStoriesMap[uid]!.add(doc);
            }
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

              // 🌟 ITEM > 0: OTHER USERS 🌟
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
                      // 🌟 2. THE FIX: Marquee తీసేసి Ellipsis పెట్టాం
                      SizedBox(
                        width: 70,
                        height: 15,
                        child: Align(
                          alignment: Alignment.center,
                          child: Text(
                            user['username'],
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            maxLines: 1, // ఒకే లైన్
                            overflow: TextOverflow.ellipsis, // ... వస్తుంది
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
