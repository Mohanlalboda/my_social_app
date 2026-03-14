import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/safe_elements.dart';
import 'post_details_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // 1. 🌟 EDIT PROFILE DIALOG
  void _showEditDialog(String currentName, String currentBio) {
    final nameCtrl = TextEditingController(text: currentName);
    final bioCtrl = TextEditingController(text: currentBio);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              String uid = FirebaseAuth.instance.currentUser!.uid;
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .update({
                    "username": nameCtrl.text.trim(),
                    "bio": bioCtrl.text.trim(),
                  });
              if (dialogContext.mounted) {
                navigator.pop();
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // 🌟 UPDATE PROFILE PICTURE (Line 80 Fixed)
  Future<void> _updateProfilePic() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 10,
      maxWidth: 300,
    );

    if (image != null) {
      // 1. await కి ముందు messenger ని తీసుకోకండి (లినర్ కొన్నిసార్లు దీన్ని ఒప్పుకోదు)
      String base64Image = base64Encode(await File(image.path).readAsBytes());
      String uid = FirebaseAuth.instance.currentUser!.uid;

      // Async gap start
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        "profilePic": base64Image,
      });
      // Async gap end

      // 🌟 అసలైన ఫిక్స్ ఇక్కడ ఉంది:
      // await తర్వాత context ని వాడే ప్రతీ చోటా కచ్చితంగా 'mounted' చెక్ ఉండాలి.
      if (!mounted) return;

      // నేరుగా ScaffoldMessenger ని ఇక్కడ వాడండి
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Profile updated! 📸")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    return DefaultTabController(
      length: 3, // 🌟 Posts, Reels, Saved
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          // ✅ FIXED: curly_braces_in_flow_control_structures (Line 104)
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var userData =
              userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          String name = userData['username'] ?? "User";
          String bio = userData['bio'] ?? "No bio yet.";
          List followers = userData['followers'] ?? [];
          List following = userData['following'] ?? [];

          return Scaffold(
            appBar: AppBar(
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: [
                // 🌟 THREE-LINE MENU (PopupMenuButton)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.menu),
                  onSelected: (value) {
                    if (value == 'edit') _showEditDialog(name, bio);
                    if (value == 'pic') _updateProfilePic();
                    if (value == 'logout') FirebaseAuth.instance.signOut();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text("Edit Profile"),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'pic',
                      child: ListTile(
                        leading: Icon(Icons.camera_alt),
                        title: Text("Change Profile Pic"),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: ListTile(
                        leading: Icon(Icons.logout, color: Colors.red),
                        title: Text(
                          "Logout",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
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
                        base64String: userData['profilePic'],
                        radius: 40,
                        fallbackText: name.isNotEmpty ? name[0] : "U",
                      ),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('posts')
                              .where('ownerId', isEqualTo: uid)
                              .snapshots(),
                          builder: (context, postSnapshot) {
                            int postCount = postSnapshot.hasData
                                ? postSnapshot.data!.docs.length
                                : 0;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _StatColumn(
                                  num: postCount.toString(),
                                  label: "Posts",
                                ),
                                _StatColumn(
                                  num: followers.length.toString(),
                                  label: "Followers",
                                ),
                                _StatColumn(
                                  num: following.length.toString(),
                                  label: "Following",
                                ),
                              ],
                            );
                          },
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
                    ],
                  ),
                ),
                const TabBar(
                  indicatorColor: Colors.red,
                  labelColor: Colors.red,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(icon: Icon(Icons.grid_on)),
                    Tab(icon: Icon(Icons.video_library)), // 🌟 Reels Tab
                    Tab(icon: Icon(Icons.bookmark_border)),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildPostGrid(
                        FirebaseFirestore.instance
                            .collection('posts')
                            .where('ownerId', isEqualTo: uid)
                            .snapshots(),
                      ),
                      // 🌟 User Reels Tab View
                      _buildReelsGrid(
                        FirebaseFirestore.instance
                            .collection('reels')
                            .where('ownerId', isEqualTo: uid)
                            .snapshots(),
                      ),
                      _buildPostGrid(
                        FirebaseFirestore.instance
                            .collection('posts')
                            .where('savedBy', arrayContains: uid)
                            .snapshots(),
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

  // 🌟 REELS GRID BUILDER
  Widget _buildReelsGrid(Stream<QuerySnapshot> stream) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        // ✅ FIXED: curly_braces_in_flow_control_structures (Line 264)
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var reels = snapshot.data!.docs;
        if (reels.isEmpty) {
          return const Center(child: Text("No Reels yet."));
        }
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 0.7,
          ),
          itemCount: reels.length,
          itemBuilder: (context, i) => Container(
            color: Colors.black12,
            child: const Icon(Icons.play_circle_outline, color: Colors.white),
          ),
        );
      },
    );
  }

  // 🌟 POST GRID BUILDER
  Widget _buildPostGrid(Stream<QuerySnapshot> stream) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        // ✅ FIXED: curly_braces_in_flow_control_structures (Line 289)
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var posts = snapshot.data!.docs;
        if (posts.isEmpty) {
          return const Center(child: Text("No posts found."));
        }
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: posts.length,
          itemBuilder: (context, i) => GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailsScreen(postId: posts[i].id),
              ),
            ),
            child: SafeImage(
              base64String: (posts[i].data() as Map)['postData'],
            ),
          ),
        );
      },
    );
  }
}

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
