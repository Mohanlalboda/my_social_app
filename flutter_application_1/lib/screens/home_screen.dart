import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/post_widget.dart';
import '../widgets/safe_elements.dart';
import 'story_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isUploading = false;

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
        String uid = FirebaseAuth.instance.currentUser!.uid;

        await FirebaseFirestore.instance.collection('stories').add({
          "uid": uid,
          "ownerId": uid,
          "username": userData['username'] ?? "User",
          "profilePic": userData['profilePic'] ?? "",
          "storyData": base64Image,
          "timestamp": FieldValue.serverTimestamp(),
        });

        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Story Added! 🌟")));
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

  Future<void> _uploadPost() async {
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
      TextEditingController captionController = TextEditingController();
      bool isPrivatePost = false;

      showDialog(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                title: const Text("New Post"),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.file(
                        File(image.path),
                        height: 150,
                        fit: BoxFit.cover,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: captionController,
                        decoration: const InputDecoration(
                          hintText: "Write a caption...",
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      SwitchListTile(
                        title: const Text("Private Post"),
                        value: isPrivatePost,
                        onChanged: (val) {
                          setStateDialog(() {
                            isPrivatePost = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      // 🌟 FIXED: context ఎర్రర్ రాకుండా ముందే messenger ని తీసుకుంటున్నాం
                      final navigator = Navigator.of(dialogContext);
                      final messenger = ScaffoldMessenger.of(context);
                      navigator.pop();

                      if (!mounted) {
                        return;
                      }
                      setState(() {
                        _isUploading = true;
                      });

                      try {
                        String base64Image = base64Encode(
                          await File(image.path).readAsBytes(),
                        );
                        String uid = FirebaseAuth.instance.currentUser!.uid;
                        String postId = DateTime.now().millisecondsSinceEpoch
                            .toString();

                        await FirebaseFirestore.instance
                            .collection('posts')
                            .doc(postId)
                            .set({
                              "postId": postId,
                              "ownerId": uid,
                              "postData": base64Image,
                              "caption": captionController.text.trim(),
                              "username": FirebaseAuth
                                  .instance
                                  .currentUser!
                                  .email!
                                  .split('@')[0],
                              "timestamp": FieldValue.serverTimestamp(),
                              "likes": {},
                              "commentCount": 0,
                              "savedBy": [],
                              "isPrivate": isPrivatePost,
                            });

                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text("Shared! 🌎")),
                          );
                        }
                      } catch (e) {
                        // 🌟 FIXED: Empty catch ఎర్రర్ రాకుండా ప్రింట్ పెట్టాం
                        debugPrint("Upload Post Error: $e");
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isUploading = false;
                          });
                        }
                      }
                    },
                    child: const Text("Share"),
                  ),
                ],
              );
            },
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFD1D1D),
        onPressed: _uploadPost,
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .snapshots(),
        builder: (context, userSnapshot) {
          // 🌟 FIXED: Added curly braces
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
                      .where(
                        'timestamp',
                        isGreaterThanOrEqualTo: yesterday,
                      ) // 🌟 24 గంటల లాజిక్
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
                      data['storyId'] =
                          doc.id; // 🌟 స్టోరీ ఐడీని కూడా పంపుతున్నాం
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

                        // 🌟 ఇది మనం చూశామా లేదా అని చెక్ చేస్తుంది
                        List viewers = userStory['viewers'] ?? [];
                        bool isSeen = viewers.contains(currentUid);

                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  StoryScreen(user: userStory),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    // 🌟 చూసేస్తే బార్డర్ ఉండదు, చూడకపోతే రంగుల బార్డర్ వస్తుంది
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
                                    padding: const EdgeInsets.all(
                                      2,
                                    ), // తెల్లటి గ్యాప్ కోసం
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
                          // 🌟 FIXED: Added curly braces
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          var feedPosts = snapshot.data!.docs
                              .where(
                                (doc) => feedUserIds.contains(doc['ownerId']),
                              )
                              .toList();

                          // 🌟 FIXED: Added curly braces
                          if (feedPosts.isEmpty) {
                            return const Center(
                              child: Text("Follow people to see posts! 🌎"),
                            );
                          }

                          return ListView.builder(
                            itemCount: feedPosts.length,
                            itemBuilder: (context, index) => PostWidget(
                              post:
                                  feedPosts[index].data()
                                      as Map<String, dynamic>,
                            ),
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
