// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use, unused_import

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

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
  bool _isUploading = false;
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  Future<void> _uploadStory(Map<String, dynamic> userData, bool isVideo) async {
    final ImagePicker picker = ImagePicker();

    if (isVideo) {
      // 🌟 వీడియో కోసం
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
          debugPrint("Video Story Upload Error: $e");
        } finally {
          if (mounted) setState(() => _isUploading = false);
        }
      }
    } else {
      // 🌟 మల్టిపుల్ ఫోటోల కోసం (ఒకేసారి ఎన్ని ఫోటోలు అయినా సెలెక్ట్ చేయొచ్చు)
      final List<XFile> files = await picker.pickMultiImage(imageQuality: 50);

      if (files.isNotEmpty) {
        if (!mounted) return;
        setState(() => _isUploading = true);

        try {
          // లూప్ వాడి ప్రతి ఫోటోని వరుసగా అప్‌లోడ్ చేస్తాం
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

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Stories Added Successfully! 🌟"),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          debugPrint("Story Upload Error: $e");
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
    // 🌟 ఫోన్ డార్క్ మోడ్ లో ఉందా లేదా అని చెక్ చేయడానికి లాజిక్
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // 🌟 బ్యాక్‌గ్రౌండ్ కలర్ తీసేశాను, ఆటోమేటిక్ గా సిస్టమ్ థీమ్ (బ్లాక్/వైట్) తీసుకుంటుంది
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFD1D1D),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddPostScreen()),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          var userData =
              userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          List feedUserIds = List.from(userData['following'] ?? [])
            ..add(currentUid);
          DateTime yesterday = DateTime.now().subtract(
            const Duration(hours: 24),
          );

          return Column(
            children: [
              // 🌟 స్టోరీ కార్డ్ సెక్షన్
              SizedBox(
                height: 110,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('stories')
                      .where('timestamp', isGreaterThanOrEqualTo: yesterday)
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
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return GestureDetector(
                            onTap: () => _showStoryPicker(userData),
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
                                            userData['username'] != null
                                            ? userData['username'][0]
                                            : "U",
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          // 🌟 డార్క్ మోడ్ బట్టి ప్లస్ ఐకాన్ బ్యాక్‌గ్రౌండ్ మారుతుంది
                                          color: isDark
                                              ? Colors.black
                                              : Colors.white,
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
                                  AutoScrollText(
                                    text: "Your Story",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      // 🌟 డార్క్ మోడ్ లో అక్షరాలు తెలుపు రంగులోకి మారుతాయి
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
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
                          onTap: () async {
                            await FirebaseFirestore.instance
                                .collection('stories')
                                .doc(userStory['storyId'])
                                .update({
                                  'viewers': FieldValue.arrayUnion([
                                    currentUid,
                                  ]),
                                });

                            if (!context.mounted) return;

                            Navigator.push(
                              context,
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
                                      // 🌟 స్టోరీ రింగ్ లోపలి కలర్ డార్క్ మోడ్ బట్టి మారుతుంది
                                      color: isDark
                                          ? Colors.black
                                          : Colors.white,
                                    ),
                                    child: SafeProfilePic(
                                      base64String: userStory['profilePic'],
                                      radius: 28,
                                      fallbackText:
                                          userStory['username'] != null
                                          ? userStory['username'][0]
                                          : "U",
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                AutoScrollText(
                                  text: userStory['username'] ?? "User",
                                  style: TextStyle(
                                    fontSize: 11,
                                    // 🌟 డార్క్ మోడ్ చెక్ చేసి రంగు ఇస్తున్నాం
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
              // పోస్ట్ ఫీడ్
              Expanded(
                child: _isUploading
                    ? const Center(child: Text("Uploading Story... ⏳"))
                    : StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('posts')
                            .orderBy('timestamp', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData)
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          var visiblePosts = snapshot.data!.docs.where((doc) {
                            var data = doc.data() as Map<String, dynamic>;
                            return feedUserIds.contains(data['ownerId']) ||
                                (data['isPublic'] ?? true);
                          }).toList();

                          return ListView.builder(
                            itemCount: visiblePosts.length,
                            itemBuilder: (context, index) {
                              var post =
                                  visiblePosts[index].data()
                                      as Map<String, dynamic>;
                              post['postId'] = visiblePosts[index].id;
                              return PostWidget(post: post);
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

// 🌟 ఆటోమాటిక్ గా స్క్రోల్ అయ్యే మ్యాజిక్ విడ్జెట్
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
    if (!mounted) return;

    while (mounted) {
      if (_scrollController.hasClients) {
        double maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll > 0) {
          // కుడి వైపుకు స్క్రోల్
          await _scrollController.animateTo(
            maxScroll,
            duration: const Duration(seconds: 2),
            curve: Curves.linear,
          );
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) break;
          // మళ్లీ ఎడమ వైపుకు (స్టార్టింగ్ కి) స్క్రోల్
          await _scrollController.animateTo(
            0,
            duration: const Duration(seconds: 2),
            curve: Curves.linear,
          );
          await Future.delayed(const Duration(seconds: 1));
        } else {
          await Future.delayed(const Duration(seconds: 2));
        }
      } else {
        await Future.delayed(const Duration(seconds: 1));
      }
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
      width: 70, // కచ్చితంగా సర్కిల్ వెడల్పు దాటి వెళ్ళదు
      child: SingleChildScrollView(
        physics:
            const NeverScrollableScrollPhysics(), // యూజర్ ఫింగర్ తో స్క్రోల్ చేయలేరు
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: Text(widget.text, style: widget.style),
      ),
    );
  }
}
