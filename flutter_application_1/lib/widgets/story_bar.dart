// ignore_for_file: use_build_context_synchronously, curly_braces_in_flow_control_structures

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

  // 🌟 యూజర్ డేటా తెచ్చుకోవడం & ఘోస్ట్ ఐడీలని క్లీన్ చేయడం
  void _fetchMyData() async {
    var doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .get();
    if (doc.exists && mounted) {
      setState(() => myUserData = doc.data());

      // 🧹 Ghost Cleanup on load
      List followers = doc.data()?['followers'] ?? [];
      List following = doc.data()?['following'] ?? [];
      _cleanGhostUsers(followers, following);
    }
  }

  // 🧹 దెయ్యం ఐడీలని (Deleted Users) పీకేసే లాజిక్
  Future<void> _cleanGhostUsers(
    List currentFollowers,
    List currentFollowing,
  ) async {
    List<String> validFollowers = [];
    List<String> validFollowing = [];
    bool needsUpdate = false;

    for (String id in currentFollowers) {
      try {
        var doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(id)
            .get();
        if (doc.exists)
          validFollowers.add(id);
        else
          needsUpdate = true;
      } catch (e) {
        needsUpdate = true;
      }
    }

    for (String id in currentFollowing) {
      try {
        var doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(id)
            .get();
        if (doc.exists)
          validFollowing.add(id);
        else
          needsUpdate = true;
      } catch (e) {
        needsUpdate = true;
      }
    }

    if (needsUpdate && mounted) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .update({'followers': validFollowers, 'following': validFollowing});
    }
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
                _pickStoryAndShowPreview(false);
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
                _pickStoryAndShowPreview(true);
              },
            ),
          ],
        ),
      ),
    );
  }

  // 🌟 THE ULTIMATE FIX FOR OVERFLOW ERROR 🌟
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

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 15,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: const Text(
                "Add Story",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              content: Builder(
                builder: (context) {
                  double keyboardHeight = MediaQuery.of(
                    context,
                  ).viewInsets.bottom;
                  return SizedBox(
                    width: MediaQuery.of(context).size.width,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        bottom: keyboardHeight > 0 ? 10 : 0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: !isVideo
                                ? Image.file(
                                    mediaFile,
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    height: 180,
                                    width: double.infinity,
                                    color: Colors.black,
                                    child: const Icon(
                                      Icons.play_circle,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 15),
                          TextField(
                            controller: captionController,
                            style: const TextStyle(color: Colors.white),
                            scrollPadding: const EdgeInsets.all(100),
                            decoration: InputDecoration(
                              hintText: "Write a caption...",
                              hintStyle: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                              filled: true,
                              fillColor: Colors.black54,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            maxLines: 2,
                          ),
                          if (isUploadingLocal) ...[
                            const SizedBox(height: 15),
                            const LinearProgressIndicator(
                              color: Color(0xFF00E5FF),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
              actions: [
                if (!isUploadingLocal)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                  ),
                  onPressed: isUploadingLocal
                      ? null
                      : () async {
                          setDialogState(() => isUploadingLocal = true);
                          String caption = captionController.text.trim();
                          Navigator.pop(ctx);
                          await _processAndUpload(mediaFile, isVideo, caption);
                        },
                  child: const Text(
                    "Share",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
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

  Future<void> _processAndUpload(
    File finalFile,
    bool isVideo,
    String caption,
  ) async {
    UploadManager().isUploading.value = true;
    try {
      UploadManager().uploadStatus.value = "Compressing... 🗜️";
      if (isVideo)
        finalFile = await UploadManager().compressVideo(finalFile);
      else
        finalFile = await UploadManager().compressImage(finalFile);

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
      });

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      DateTime expiryTime = DateTime.now().add(const Duration(hours: 24));

      await FirebaseFirestore.instance.collection('stories').add({
        "uid": currentUid,
        "ownerId": currentUid,
        "username": myUserData!['username'] ?? "User",
        "profilePic": myUserData!['profilePic'] ?? "",
        "storyUrl": downloadUrl,
        "type": isVideo ? "video" : "image",
        "caption": caption,
        "timestamp": FieldValue.serverTimestamp(),
        "expiresAt": Timestamp.fromDate(expiryTime),
        "likes": [],
        "viewers": [],
      });

      UploadManager().uploadStatus.value = "Success! 🎉";
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      UploadManager().uploadStatus.value = "❌ Error";
    } finally {
      UploadManager().isUploading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
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
            if (uid != currentUid) {
              if (hasUnseen)
                unseenUsers.add(userData);
              else
                seenUsers.add(userData);
            }
          });

          List<Map<String, dynamic>> finalUsersList = [
            ...unseenUsers,
            ...seenUsers,
          ];
          bool hasMyStory = userStoriesMap.containsKey(currentUid);
          bool hasMyStoryUnseen =
              hasMyStory &&
              userStoriesMap[currentUid]!.any(
                (doc) => !(doc['viewers'] as List).contains(currentUid),
              );

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            itemCount: finalUsersList.length + 1,
            itemBuilder: (context, index) {
              if (index == 0)
                return _buildMyStoryItem(isDark, hasMyStory, hasMyStoryUnseen);
              var user = finalUsersList[index - 1];
              return _buildOtherStoryItem(
                user,
                isDark,
                index - 1,
                finalUsersList,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMyStoryItem(bool isDark, bool hasStory, bool hasUnseen) {
    return GestureDetector(
      onTap: hasStory
          ? () => _viewStories([
              {
                'uid': currentUid,
                'username': myUserData?['username'],
                'profilePic': myUserData?['profilePic'],
              },
            ], 0)
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
                    gradient: hasStory
                        ? (hasUnseen ? brandGradient : null)
                        : null,
                    border: hasStory && !hasUnseen
                        ? Border.all(color: Colors.grey, width: 2)
                        : (hasStory
                              ? null
                              : Border.all(color: Colors.grey, width: 1)),
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
                          myUserData?['username']?.toString().isNotEmpty == true
                          ? myUserData!['username'][0]
                          : "Y",
                    ),
                  ),
                ),
                if (!hasStory)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? Colors.black : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 16),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              "Your Story",
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherStoryItem(
    Map<String, dynamic> user,
    bool isDark,
    int index,
    List<Map<String, dynamic>> list,
  ) {
    return GestureDetector(
      onTap: () => _viewStories(list, index),
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
              child: Text(
                user['username'],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white : Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🌟 THE FIX: ఇక్కడ dynamic లిస్ట్ ని Map లిస్ట్ గా పక్కాగా మారుస్తున్నాం
  void _viewStories(List<dynamic> users, int index) {
    List<Map<String, dynamic>> formattedUsers = users
        .map((e) => e as Map<String, dynamic>)
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryViewScreen(
          usersWithStories: formattedUsers,
          initialUserIndex: index,
        ),
      ),
    );
  }
}
