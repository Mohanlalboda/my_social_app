// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';

import 'scrolling_posts_screen.dart';
import 'scrolling_reels_screen.dart';
import '../widgets/safe_elements.dart';
import 'user_list_screen.dart';
import 'add_post_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  // 🛠️ 1. Settings & Privacy Sheet
  void _showSettings(bool currentPrivateStatus) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
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
                  subtitle: const Text(
                    "When your account is public, anyone can see your photos and videos.",
                  ),
                  value: currentPrivateStatus,
                  activeThumbColor: Colors.blue,
                  onChanged: (val) async {
                    setModalState(() => currentPrivateStatus = val);
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .update({'isPrivate': val});
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  // 🛠️ 2. Profile Actions (View/Change Picture)
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
            Container(
              alignment: Alignment.center,
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline, size: 28),
              title: const Text("View Profile Picture"),
              onTap: () {
                Navigator.pop(ctx);
                _showFullProfilePic(picUrl, name);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: Colors.blue,
                size: 28,
              ),
              title: const Text(
                "Change Profile Picture",
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _updateProfilePic();
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // 🛠️ 3. Main Menu Sheet
  void _showInstagramMenu(String name, String bio, bool isPrivate) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
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
                title: const Text(
                  "Logout",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  FirebaseAuth.instance.signOut();
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // 🛠️ 4. Profile Operations (Edit, Upload Pic, Story)
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
      imageQuality: 85,
    );
    if (image != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Uploading... ⏳")));
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile updated! 📸"),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        debugPrint("Pic Upload Error: $e");
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
            Hero(
              tag: 'p_zoom',
              child: SafeProfilePic(
                base64String: base64String,
                radius: 150,
                fallbackText: name.isNotEmpty ? name[0] : "U",
              ),
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

  Future<void> _uploadStory(Map<String, dynamic> userData, bool isVideo) async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = isVideo
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Uploading Story... ⏳")));
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Story Added! ✅"),
            backgroundColor: Colors.green,
          ),
        );
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
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Hero(
                                  tag: 'p_zoom',
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
                                  child: ElevatedButton(
                                    onPressed: () => _showEditDialog(name, bio),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDark
                                          ? Colors.grey[900]
                                          : Colors.grey[200],
                                      foregroundColor: isDark
                                          ? Colors.white
                                          : Colors.black,
                                      elevation: 0,
                                    ),
                                    child: const Text("Edit profile"),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      SharePlus.instance.share(
                                        ShareParams(
                                          text:
                                              "Check my profile: @$name on MyBanjara!",
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDark
                                          ? Colors.grey[900]
                                          : Colors.grey[200],
                                      foregroundColor: isDark
                                          ? Colors.white
                                          : Colors.black,
                                      elevation: 0,
                                    ),
                                    child: const Text("Share profile"),
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
                                    () => _showStoryPicker(userData),
                                  ),
                                  _buildHighlightCircle(
                                    "Moments",
                                    false,
                                    isDark,
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
                    TabBar(
                      indicatorColor: isDark ? Colors.white : Colors.black,
                      labelColor: isDark ? Colors.white : Colors.black,
                      unselectedLabelColor: Colors.grey,
                      tabs: const [
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
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                child: isNew
                    ? Icon(
                        Icons.add,
                        color: isDark ? Colors.white : Colors.black,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 5),
            Text(title, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // 🖼️ 5. Grids with Thumbnails
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
        List<String> ids = posts.map((d) => d.id).toList();
        if (posts.isEmpty) return const Center(child: Text("No posts yet."));
        return GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: shrinkWrap,
          physics: physics ?? const BouncingScrollPhysics(),
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
              child: SafeImage(base64String: thumb),
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
                  ReelGridPreview(videoUrl: url),
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
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.65,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: reels.length, // 🌟 FIXED: Removed duplicate itemCount
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
              child: ReelGridPreview(videoUrl: url),
            );
          },
        );
      },
    );
  }
}

// 🏛️ Helper Classes
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

// 🌟 REELS PREVIEW (Thumbnail Logic)
class ReelGridPreview extends StatefulWidget {
  final String videoUrl;
  const ReelGridPreview({super.key, required this.videoUrl});
  @override
  State<ReelGridPreview> createState() => _ReelGridPreviewState();
}

class _ReelGridPreviewState extends State<ReelGridPreview> {
  late CachedVideoPlayerPlus _player;
  bool _init = false;
  @override
  void initState() {
    super.initState();
    if (widget.videoUrl.isNotEmpty) {
      _player = CachedVideoPlayerPlus.networkUrl(Uri.parse(widget.videoUrl))
        ..initialize().then((_) {
          if (mounted) setState(() => _init = true);
        });
    }
  }

  @override
  void dispose() {
    if (_init) _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _init
      ? FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _player.controller.value.size.width,
            height: _player.controller.value.size.height,
            child: VideoPlayer(_player.controller),
          ),
        )
      : Container(
          color: Colors.grey[900],
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
}
