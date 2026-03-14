import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 🌟 Widgets మరియు Screens ఇంపార్ట్స్
import '../widgets/safe_elements.dart';
import 'post_details_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // 🌟 ప్రొఫైల్ ఎడిట్ డైలాగ్
  void _showEditDialog(String currentName, String currentBio) {
    final nameCtrl = TextEditingController(text: currentName);
    final bioCtrl = TextEditingController(text: currentBio);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Profile"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            TextField(
              controller: bioCtrl,
              decoration: const InputDecoration(labelText: "Bio"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              String uid = FirebaseAuth.instance.currentUser!.uid;
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .update({
                    "username": nameCtrl.text.trim(),
                    "bio": bioCtrl.text.trim(),
                  });
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // 🌟 ప్రొఫైల్ పిక్చర్ అప్‌డేట్
  Future<void> _updateProfilePic() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 10,
      maxWidth: 300,
    );
    if (image != null) {
      String base64Image = base64Encode(await File(image.path).readAsBytes());
      String uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        "profilePic": base64Image,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Profile updated! 📸")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;
    return DefaultTabController(
      length: 2,
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          // 🌟 FIXED: Added curly braces
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          String name = userData['username'] ?? "User";
          String profilePic = userData['profilePic'] ?? "";
          String bio = userData['bio'] ?? "No bio yet.";

          return Scaffold(
            appBar: AppBar(
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.camera_alt_outlined),
                  onPressed: _updateProfilePic,
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.red),
                  onPressed: () => FirebaseAuth.instance.signOut(),
                ),
              ],
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      SafeProfilePic(
                        base64String: profilePic,
                        radius: 40,
                        fallbackText: name,
                      ),
                      const Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _StatColumn(num: "0", label: "Posts"),
                            _StatColumn(num: "0", label: "Followers"),
                            _StatColumn(num: "0", label: "Following"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(bio),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _showEditDialog(name, bio),
                          child: const Text("Edit Profile"),
                        ),
                      ),
                    ],
                  ),
                ),
                const TabBar(
                  indicatorColor: Colors.red,
                  labelColor: Colors.red,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(icon: Icon(Icons.grid_on)),
                    Tab(icon: Icon(Icons.bookmark_border)),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // 🌟 Tab 1: My Posts
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('posts')
                            .where('ownerId', isEqualTo: uid)
                            .snapshots(),
                        builder: (context, s) {
                          // 🌟 FIXED: Added curly braces
                          if (!s.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          var posts = s.data!.docs;
                          if (posts.isEmpty) {
                            return const Center(child: Text("No posts yet!"));
                          }
                          return GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 2,
                                  mainAxisSpacing: 2,
                                ),
                            itemCount: posts.length,
                            itemBuilder: (context, i) => GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PostDetailsScreen(postId: posts[i].id),
                                ),
                              ),
                              child: SafeImage(
                                base64String:
                                    (posts[i].data() as Map)['postData'],
                              ),
                            ),
                          );
                        },
                      ),
                      // 🌟 Tab 2: Saved Posts
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('posts')
                            .where('savedBy', arrayContains: uid)
                            .snapshots(),
                        builder: (context, s) {
                          // 🌟 FIXED: Added curly braces
                          if (!s.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          var saved = s.data!.docs;
                          if (saved.isEmpty) {
                            return const Center(
                              child: Text("No saved posts yet 📌"),
                            );
                          }
                          return GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 2,
                                  mainAxisSpacing: 2,
                                ),
                            itemCount: saved.length,
                            itemBuilder: (context, i) => GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PostDetailsScreen(postId: saved[i].id),
                                ),
                              ),
                              child: SafeImage(
                                base64String:
                                    (saved[i].data() as Map)['postData'],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// 🌟 స్టాట్ కాలమ్ విడ్జెట్
class _StatColumn extends StatelessWidget {
  final String num;
  final String label;
  const _StatColumn({required this.num, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          num,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
