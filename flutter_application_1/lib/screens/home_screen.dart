import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// మనం విడగొట్టిన విడ్జెట్స్ మరియు స్క్రీన్స్ ఇంపోర్ట్స్
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

  // 🌟 STORY UPLOAD LOGIC
  Future<void> _uploadStory() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 15,
      maxWidth: 600,
    );

    if (image != null) {
      // ఏవైనా మార్పులు చేసే ముందు విడ్జెట్ ఇంకా స్క్రీన్ మీద ఉందో లేదో చెక్ చేయాలి
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
          "ownerId": uid,
          "storyData": base64Image,
          "timestamp": FieldValue.serverTimestamp(),
        });

        // 🌟 FIXED: Guard check after async gap
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

  // 🌟 POST UPLOAD LOGIC
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
                  // ... (మునుపటి imports)

                  // _uploadPost మెథడ్ లోపల ఈ మార్పు చేసాను:
                  ElevatedButton(
                    onPressed: () async {
                      final navigator = Navigator.of(dialogContext);
                      final messenger = ScaffoldMessenger.of(context);

                      navigator.pop();

                      if (!mounted) return;
                      setState(() => _isUploading = true);

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

                        // 🌟 FIXED: Use mounted check strictly here
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text("Shared! 🌎")),
                          );
                        }
                      } catch (e) {
                        debugPrint(e.toString());
                      } finally {
                        if (mounted) {
                          setState(() => _isUploading = false);
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
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var userData =
              userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          List following = userData['following'] ?? [];
          List feedUserIds = List.from(following)..add(currentUid);

          return Column(
            children: [
              SizedBox(
                height: 110,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox();
                    }
                    var storyUsers = snapshot.data!.docs
                        .where((doc) => feedUserIds.contains(doc['uid']))
                        .toList();

                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: storyUsers.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return GestureDetector(
                            onTap: _uploadStory,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                children: [
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      SafeProfilePic(
                                        base64String: userData['profilePic'],
                                        radius: 35,
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
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Text(
                                    "Your Story",
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        var user =
                            storyUsers[index - 1].data()
                                as Map<String, dynamic>;
                        return GestureDetector(
                          onTap: () {
                            // 🌟 FIXED: Navigation inside curly braces
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StoryScreen(user: user),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.purple,
                                        Colors.red,
                                        Colors.orange,
                                      ],
                                    ),
                                  ),
                                  child: SafeProfilePic(
                                    base64String: user['profilePic'],
                                    radius: 30,
                                    fallbackText: user['username'] ?? "U",
                                  ),
                                ),
                                Text(
                                  user['username'],
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
                          // 🌟 FIXED: Added curly braces (Line 330 error)
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

                          // 🌟 FIXED: Added curly braces (Line 341 error)
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
