// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'single_reel_screen.dart';
import 'scrolling_posts_screen.dart';
import '../widgets/safe_elements.dart';
import 'user_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
              String uid = FirebaseAuth.instance.currentUser!.uid;
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .update({
                    "username": nameCtrl.text.trim(),
                    "bio": bioCtrl.text.trim(),
                  });
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

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
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Profile updated! 📸")));
    }
  }

  void _showFullProfilePic(String base64String, String fallbackName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(
              tag: 'profilePic_zoom',
              child: SafeProfilePic(
                base64String: base64String,
                radius: 150,
                fallbackText: fallbackName.isNotEmpty ? fallbackName[0] : "U",
              ),
            ),
            const SizedBox(height: 20),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    return DefaultTabController(
      length: 3,
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          var userData =
              userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          String name = userData['username'] ?? "User";
          String bio = userData['bio'] ?? "No bio yet.";
          List followers = userData['followers'] ?? [];
          List following = userData['following'] ?? [];
          List savedReels = userData['saved_reels'] ?? [];

          return Scaffold(
            appBar: AppBar(
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: [
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
                        title: Text("Change Pic"),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: ListTile(
                        leading: Icon(Icons.logout, color: Colors.red),
                        title: Text("Logout"),
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
                      GestureDetector(
                        onTap: () => _showFullProfilePic(
                          userData['profilePic'] ?? "",
                          name,
                        ),
                        child: Hero(
                          tag: 'profilePic_zoom',
                          child: SafeProfilePic(
                            base64String: userData['profilePic'],
                            radius: 40,
                            fallbackText: name.isNotEmpty ? name[0] : "U",
                          ),
                        ),
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
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => UserListScreen(
                                        title: "Followers",
                                        userIds: followers,
                                      ),
                                    ),
                                  ),
                                  child: _StatColumn(
                                    num: followers.length.toString(),
                                    label: "Followers",
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => UserListScreen(
                                        title: "Following",
                                        userIds: following,
                                      ),
                                    ),
                                  ),
                                  child: _StatColumn(
                                    num: following.length.toString(),
                                    label: "Following",
                                  ),
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
                    Tab(icon: Icon(Icons.video_library)),
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
                      _buildReelsGrid(
                        FirebaseFirestore.instance
                            .collection('reels')
                            .where('uid', isEqualTo: uid)
                            .snapshots(),
                      ),
                      _buildSavedTab(uid, savedReels),
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

  Widget _buildSavedTab(String uid, List<dynamic> savedReelIds) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            "📌 Saved Posts",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        _buildPostGrid(
          FirebaseFirestore.instance
              .collection('posts')
              .where('savedBy', arrayContains: uid)
              .snapshots(),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
        ),
        const Divider(height: 30, thickness: 1),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            "🎬 Saved Reels",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        _buildSavedReelsGrid(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildReelsGrid(Stream<QuerySnapshot> stream) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var reels = snapshot.data!.docs;
        if (reels.isEmpty) return const Center(child: Text("No Reels yet. 🎬"));

        return GridView.builder(
          shrinkWrap: true,
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.7,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: reels.length,
          itemBuilder: (context, i) {
            var reelData = reels[i].data() as Map<String, dynamic>;
            String reelId = reelData['reelId'] ?? reels[i].id;
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SingleReelScreen(reelId: reelId),
                ),
              ),
              child: Container(
                color: Colors.black,
                child: const Center(
                  child: Icon(Icons.play_arrow, color: Colors.white, size: 40),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSavedReelsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reels')
          .where(
            'savedBy',
            arrayContains: FirebaseAuth.instance.currentUser!.uid,
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var savedReels = snapshot.data!.docs;
        if (savedReels.isEmpty)
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                "No saved reels yet. 🎬\n(Try saving a reel first!)",
                textAlign: TextAlign.center,
              ),
            ),
          );

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.7,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: savedReels.length,
          itemBuilder: (context, index) {
            var reelData = savedReels[index].data() as Map<String, dynamic>;
            String reelDocId = reelData['reelId'] ?? savedReels[index].id;
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SingleReelScreen(reelId: reelDocId),
                ),
              ),
              child: Container(
                color: Colors.black,
                child: const Icon(
                  Icons.bookmark,
                  color: Colors.white24,
                  size: 30,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPostGrid(
    Stream<QuerySnapshot> stream, {
    bool shrinkWrap = false,
    ScrollPhysics? physics,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var posts = snapshot.data!.docs;
        if (posts.isEmpty) return const Center(child: Text("No posts found."));
        List<String> postIds = posts.map((doc) => doc.id).toList();

        return GridView.builder(
          shrinkWrap: shrinkWrap,
          physics: physics ?? const AlwaysScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: posts.length,
          itemBuilder: (context, i) {
            // 🌟 కొత్త URL ఇమేజ్ కి, పాత Base64 ఇమేజ్ కి సపోర్ట్ చేసే లాజిక్
            var postData = posts[i].data() as Map<String, dynamic>;
            String thumbnail = "";

            if (postData['postData'] is List &&
                (postData['postData'] as List).isNotEmpty) {
              thumbnail = postData['postData'][0].toString();
            } else {
              thumbnail = postData['postData']?.toString() ?? "";
            }

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ScrollingPostsScreen(postIds: postIds, initialIndex: i),
                ),
              ),
              child: thumbnail.startsWith('http')
                  ? Image.network(
                      thumbnail,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image),
                      ),
                    )
                  : SafeImage(base64String: thumbnail),
            );
          },
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
