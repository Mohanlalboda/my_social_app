// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:share_plus/share_plus.dart';

import 'scrolling_posts_screen.dart';
import 'scrolling_reels_screen.dart';
import '../widgets/safe_elements.dart';
import '../widgets/cached_media_widget.dart';
import 'user_list_screen.dart';
import 'add_post_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  final LinearGradient brandGradient = const LinearGradient(
    colors: [
      Color(0xFF833AB4),
      Color(0xFFFD1D1D),
      Color(0xFFF56040),
      Color(0xFFFFDC80),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  void _showSettings(bool currentPrivateStatus) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(15.0),
              child: Text(
                "Settings and privacy",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            SwitchListTile(
              secondary: const Icon(Icons.lock_outline),
              title: const Text("Private Account"),
              value: currentPrivateStatus,
              // 🌟 ఫిక్స్ 1: activeColor బదులు activeThumbColor వాడాను
              activeThumbColor: const Color(0xFFFD1D1D),
              onChanged: (val) async {
                Navigator.pop(ctx);
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update({'isPrivate': val});
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _onProfilePicAction(String picUrl, String name) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text("View Profile Picture"),
              onTap: () {
                Navigator.pop(ctx);
                _showFullProfilePic(picUrl, name);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: Color(0xFFFD1D1D),
              ),
              title: const Text(
                "Change Profile Picture",
                style: TextStyle(
                  color: Color(0xFFFD1D1D),
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _updateProfilePic();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showInstagramMenu(String name, String bio, bool isPrivate) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text("Settings and privacy"),
              onTap: () {
                Navigator.pop(ctx);
                _showSettings(isPrivate);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout", style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                FirebaseAuth.instance.signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(String currentName, String currentBio) {
    final nameCtrl = TextEditingController(text: currentName);
    final bioCtrl = TextEditingController(text: currentBio);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFD1D1D),
            ),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .update({
                    "username": nameCtrl.text.trim(),
                    "bio": bioCtrl.text.trim(),
                  });
              Navigator.pop(ctx);
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProfilePic() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image != null) {
      try {
        var storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_pics')
            .child('$uid.jpg');
        await storageRef.putFile(File(image.path));
        String downloadUrl = await storageRef.getDownloadURL();
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          "profilePic": downloadUrl,
        });
      } catch (e) {
        debugPrint("Upload Error: $e");
      }
    }
  }

  void _showFullProfilePic(String base64String, String name) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SafeProfilePic(
              base64String: base64String,
              radius: 150,
              fallbackText: name.isNotEmpty ? name[0] : "U",
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showStoryPicker(Map<String, dynamic> userData) {
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
                Navigator.pop(context);
                _uploadStory(userData, false);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.video_collection,
                color: Color(0xFF833AB4),
              ),
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

  Future<void> _uploadStory(Map<String, dynamic> userData, bool isVideo) async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = isVideo
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      try {
        String storyId = DateTime.now().millisecondsSinceEpoch.toString();
        Reference ref = FirebaseStorage.instance
            .ref()
            .child('stories')
            .child(uid)
            .child(storyId);
        await ref.putFile(File(file.path));
        String downloadUrl = await ref.getDownloadURL();
        await FirebaseFirestore.instance.collection('stories').add({
          "uid": uid,
          "ownerId": uid,
          "username": userData['username'] ?? "User",
          "profilePic": userData['profilePic'] ?? "",
          "storyUrl": downloadUrl,
          "type": isVideo ? "video" : "image",
          "timestamp": FieldValue.serverTimestamp(),
          "viewers": [],
        });
      } catch (e) {
        debugPrint("Story Error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

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
          String bio = userData['bio'] ?? "";
          bool isPrivate = userData['isPrivate'] ?? false;
          List followers = userData['followers'] ?? [];
          List following = userData['following'] ?? [];

          return Scaffold(
            backgroundColor: isDark ? Colors.black : Colors.white,
            appBar: AppBar(
              backgroundColor: isDark ? Colors.black : Colors.white,
              elevation: 0,
              title: Row(
                children: [
                  if (isPrivate)
                    Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  const SizedBox(width: 5),
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_box_outlined, size: 28),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddPostScreen()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.menu, size: 28),
                  onPressed: () => _showInstagramMenu(name, bio, isPrivate),
                ),
              ],
            ),
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => _onProfilePicAction(
                                userData['profilePic'] ?? "",
                                name,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: brandGradient,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark ? Colors.black : Colors.white,
                                  ),
                                  child: SafeProfilePic(
                                    base64String: userData['profilePic'],
                                    radius: 40,
                                    fallbackText: name.isNotEmpty
                                        ? name[0]
                                        : "U",
                                  ),
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _StatColumn(
                                        num: postCount.toString(),
                                        label: "Posts",
                                      ),
                                      GestureDetector(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => UserListScreen(
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
                                            builder: (_) => UserListScreen(
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
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (bio.isNotEmpty) Text(bio),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _showEditDialog(name, bio),
                                    child: Container(
                                      height: 38,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        gradient: brandGradient,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        "Edit profile",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      SharePlus.instance.share(
                                        ShareParams(
                                          text:
                                              "Check my profile: @$name on MyBanjara!",
                                        ),
                                      );
                                    },
                                    child: Container(
                                      height: 38,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        gradient: brandGradient,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        "Share profile",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            SizedBox(
                              height: 85,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _buildHighlightCircle(
                                    "New",
                                    true,
                                    isDark,
                                    brandGradient,
                                    () => _showStoryPicker(userData),
                                  ),
                                  _buildHighlightCircle(
                                    "Moments",
                                    false,
                                    isDark,
                                    brandGradient,
                                    () {},
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    const TabBar(
                      indicatorColor: Color(0xFFFD1D1D),
                      labelColor: Color(0xFFFD1D1D),
                      unselectedLabelColor: Colors.grey,
                      tabs: [
                        Tab(icon: Icon(Icons.grid_on)),
                        Tab(icon: Icon(Icons.smart_display_outlined)),
                        Tab(icon: Icon(Icons.bookmark_border)),
                      ],
                    ),
                    isDark ? Colors.black : Colors.white,
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  _buildPostGrid(
                    FirebaseFirestore.instance
                        .collection('posts')
                        .where('ownerId', isEqualTo: uid)
                        .where('type', isEqualTo: 'image')
                        .snapshots(),
                  ),
                  _buildReelsGrid(
                    FirebaseFirestore.instance
                        .collection('posts')
                        .where('ownerId', isEqualTo: uid)
                        .where('type', isEqualTo: 'video')
                        .snapshots(),
                  ),
                  _buildSavedTab(uid),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHighlightCircle(
    String title,
    bool isNew,
    bool isDark,
    Gradient gradient,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 15),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: gradient,
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.black : Colors.white,
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: isDark ? Colors.grey[900] : Colors.grey[200],
                  child: isNew
                      ? Icon(
                          Icons.add,
                          color: isDark ? Colors.white : Colors.black,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(title, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildPostGrid(Stream<QuerySnapshot> stream) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var posts = snapshot.data!.docs;
        List<String> ids = posts.map((d) => d.id).toList();
        if (posts.isEmpty) return const Center(child: Text("No posts yet."));
        return GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
          ),
          itemCount: posts.length,
          itemBuilder: (context, i) {
            var data = posts[i].data() as Map<String, dynamic>;
            String thumb =
                (data['postData'] is List &&
                    (data['postData'] as List).isNotEmpty)
                ? data['postData'][0]
                : "";
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ScrollingPostsScreen(postIds: ids, initialIndex: i),
                ),
              ),
              child: thumb.startsWith('http')
                  ? CachedMediaWidget(mediaUrl: thumb, type: 'image')
                  : SafeImage(base64String: thumb),
            );
          },
        );
      },
    );
  }

  Widget _buildReelsGrid(Stream<QuerySnapshot> stream) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var reels = snapshot.data!.docs;
        List<String> ids = reels.map((d) => d.id).toList();
        if (reels.isEmpty) return const Center(child: Text("No Reels yet."));
        return GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.65,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: reels.length,
          itemBuilder: (context, i) {
            var data = reels[i].data() as Map<String, dynamic>;
            String url =
                (data['postData'] is List &&
                    (data['postData'] as List).isNotEmpty)
                ? data['postData'][0]
                : (data['storyUrl'] ?? "");
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ScrollingReelsScreen(reelIds: ids, initialIndex: i),
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedMediaWidget(mediaUrl: url, type: 'video'),
                  const Positioned(
                    top: 5,
                    right: 5,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSavedTab(String uid) {
    return ListView(
      children: [
        // 🌟 ఫిక్స్ 2: const కీవర్డ్ యాడ్ చేశాను (Better Performance)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            "📌 Saved Posts",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        _buildPostGrid(
          FirebaseFirestore.instance
              .collection('posts')
              .where('type', isEqualTo: 'image')
              .where('savedBy', arrayContains: uid)
              .snapshots(),
        ),
        const Divider(height: 30),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            "🎬 Saved Reels",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        _buildSavedReelsGrid(uid),
      ],
    );
  }

  Widget _buildSavedReelsGrid(String currentUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('type', isEqualTo: 'video')
          .where('savedBy', arrayContains: currentUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        var reels = snapshot.data!.docs;
        List<String> ids = reels.map((d) => d.id).toList();
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.65,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: reels.length,
          itemBuilder: (context, i) {
            var data = reels[i].data() as Map<String, dynamic>;
            String url =
                (data['postData'] is List &&
                    (data['postData'] as List).isNotEmpty)
                ? data['postData'][0]
                : "";
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ScrollingReelsScreen(reelIds: ids, initialIndex: i),
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedMediaWidget(mediaUrl: url, type: 'video'),
                  const Positioned(
                    top: 5,
                    right: 5,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// 🌟 ఫిక్స్: _StatColumn కి const కీవర్డ్ యాడ్ చేశాను
class _StatColumn extends StatelessWidget {
  final String num, label;
  const _StatColumn({required this.num, required this.label});
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        num,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
    ],
  );
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color _color;
  _SliverAppBarDelegate(this._tabBar, this._color);
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(context, double offset, bool overlap) =>
      Container(color: _color, child: _tabBar);
  @override
  bool shouldRebuild(_SliverAppBarDelegate old) => false;
}
