// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:share_plus/share_plus.dart';

import 'scrolling_posts_screen.dart';
import 'scrolling_reels_screen.dart'; // 🌟 మ్యాజిక్ ఇక్కడే: స్క్రోలింగ్ రీల్స్ స్క్రీన్ తెచ్చాం!
import '../widgets/safe_elements.dart';
import 'user_list_screen.dart';
import 'add_post_screen.dart';
import 'search_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
                    String uid = FirebaseAuth.instance.currentUser!.uid;
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
                leading: const Icon(Icons.local_activity_outlined),
                title: const Text("Your activity"),
                onTap: () => _showComingSoon(),
              ),
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: const Text("Archive"),
                onTap: () => _showComingSoon(),
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner),
                title: const Text("QR code"),
                onTap: () => _showComingSoon(),
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_border),
                title: const Text("Saved"),
                onTap: () => _showComingSoon(),
              ),
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text("Close Friends"),
                onTap: () => _showComingSoon(),
              ),
              ListTile(
                leading: const Icon(Icons.star_border),
                title: const Text("Favorites"),
                onTap: () => _showComingSoon(),
              ),
              const Divider(),
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

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Feature coming soon! 🚀"),
        duration: Duration(seconds: 1),
      ),
    );
  }

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
              title: const Text(
                "View Profile Picture",
                style: TextStyle(fontSize: 16),
              ),
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
                  fontSize: 16,
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

  Future<void> _updateProfilePic() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Uploading HD Profile Pic... ⏳")),
      );
      try {
        File file = File(image.path);
        String uid = FirebaseAuth.instance.currentUser!.uid;
        var storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_pics')
            .child('$uid.jpg');
        await storageRef.putFile(file);
        String downloadUrl = await storageRef.getDownloadURL();
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          "profilePic": downloadUrl,
        });
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Profile updated! 📸"),
              backgroundColor: Colors.green,
            ),
          );
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Upload Failed: $e"),
              backgroundColor: Colors.red,
            ),
          );
      }
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

  Future<void> _uploadStory(Map<String, dynamic> userData, bool isVideo) async {
    final ImagePicker picker = ImagePicker();
    String currentUid = FirebaseAuth.instance.currentUser!.uid;

    if (isVideo) {
      final XFile? file = await picker.pickVideo(source: ImageSource.gallery);
      if (file != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Uploading Story... ⏳")));
        try {
          String storyId = DateTime.now().millisecondsSinceEpoch.toString();
          Reference ref = FirebaseStorage.instance
              .ref()
              .child('stories')
              .child(currentUid)
              .child(storyId);
          await ref.putFile(File(file.path));
          String downloadUrl = await ref.getDownloadURL();
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
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Story Added! ✅",
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.green,
              ),
            );
        } catch (e) {
          debugPrint("Story Upload Error: $e");
        }
      }
    } else {
      final List<XFile> files = await picker.pickMultiImage(imageQuality: 50);
      if (files.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Uploading Story... ⏳")));
        try {
          for (var file in files) {
            String storyId = DateTime.now().millisecondsSinceEpoch.toString();
            Reference ref = FirebaseStorage.instance
                .ref()
                .child('stories')
                .child(currentUid)
                .child(storyId);
            await ref.putFile(File(file.path));
            String downloadUrl = await ref.getDownloadURL();
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
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Story Added! ✅",
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.green,
              ),
            );
        } catch (e) {
          debugPrint("Story Upload Error: $e");
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;
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
          List savedReels = userData['saved_reels'] ?? [];

          return Scaffold(
            backgroundColor: isDark ? Colors.black : Colors.white,
            appBar: AppBar(
              backgroundColor: isDark ? Colors.black : Colors.white,
              elevation: 0,
              title: Row(
                children: [
                  if (isPrivate) ...[
                    Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    const SizedBox(width: 5),
                  ],
                  // 🌟 మ్యాజిక్ ఇక్కడే: ఆ డౌన్ ఆరో (Down Arrow) ని పీకేశాం!
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
                  icon: Icon(
                    Icons.add_box_outlined,
                    color: isDark ? Colors.white : Colors.black,
                    size: 28,
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddPostScreen()),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.menu,
                    color: isDark ? Colors.white : Colors.black,
                    size: 28,
                  ),
                  onPressed: () => _showInstagramMenu(name, bio, isPrivate),
                ),
              ],
            ),
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
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
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  child: Hero(
                                    tag: 'profilePic_zoom',
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
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              if (bio.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  bio,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 15),

                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          _showEditDialog(name, bio),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDark
                                            ? Colors.grey[900]
                                            : Colors.grey[200],
                                        foregroundColor: isDark
                                            ? Colors.white
                                            : Colors.black,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        "Edit profile",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        SharePlus.instance.share(
                                          ShareParams(
                                            text:
                                                "Hey! Check out my profile on MyBanjara: @$name! Let's connect. 🚀",
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
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        "Share profile",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.grey[900]
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.person_add_outlined,
                                        size: 20,
                                      ),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const SearchScreen(),
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
                                      () => _showStoryPicker(userData),
                                    ),
                                    _buildHighlightCircle(
                                      "Travel",
                                      false,
                                      isDark,
                                      _showComingSoon,
                                    ),
                                    _buildHighlightCircle(
                                      "Food",
                                      false,
                                      isDark,
                                      _showComingSoon,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SliverPersistentHeader(
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        indicatorColor: isDark ? Colors.white : Colors.black,
                        indicatorWeight: 1,
                        labelColor: isDark ? Colors.white : Colors.black,
                        unselectedLabelColor: Colors.grey,
                        tabs: const [
                          Tab(icon: Icon(Icons.grid_on, size: 26)),
                          Tab(
                            icon: Icon(Icons.smart_display_outlined, size: 30),
                          ),
                          Tab(icon: Icon(Icons.bookmark_border, size: 26)),
                        ],
                      ),
                      isDark ? Colors.black : Colors.white,
                    ),
                    pinned: true,
                  ),
                ];
              },
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
                        .where('type', isEqualTo: 'video')
                        .where('ownerId', isEqualTo: uid)
                        .snapshots(),
                  ),
                  _buildSavedTab(uid, savedReels),
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
                border: Border.all(color: Colors.grey.shade400, width: 1),
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

  Widget _buildSavedTab(String uid, List<dynamic> savedReelIds) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
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
              .where('type', isNotEqualTo: 'video')
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

        // 🌟 ఇక్కడ పాత SingleReelScreen బదులు లిస్ట్ పాస్ చేస్తున్నాం
        List<String> reelIds = reels
            .map(
              (doc) =>
                  (doc.data() as Map<String, dynamic>)['postId']?.toString() ??
                  doc.id,
            )
            .toList();

        return GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.56,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
          ),
          itemCount: reels.length,
          itemBuilder: (context, i) {
            return GestureDetector(
              // 🌟 మ్యాజిక్: ScrollingReelsScreen కి కనెక్ట్ చేసాం
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ScrollingReelsScreen(reelIds: reelIds, initialIndex: i),
                ),
              ),
              child: Container(
                color: Colors.grey[900],
                child: const Center(
                  child: Icon(Icons.play_arrow, color: Colors.white, size: 30),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSavedReelsGrid() {
    final String currentUid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('type', isEqualTo: 'video')
          .where('savedBy', arrayContains: currentUid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        var savedReels = snapshot.data?.docs ?? [];
        if (savedReels.isEmpty)
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text("No Saved Reels Yet"),
            ),
          );

        // 🌟 సేవ్ చేసిన రీల్స్ కి కూడా లిస్ట్ పాస్ చేస్తున్నాం
        List<String> reelIds = savedReels
            .map(
              (doc) =>
                  (doc.data() as Map<String, dynamic>)['postId']?.toString() ??
                  doc.id,
            )
            .toList();

        return GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: savedReels.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
            childAspectRatio: 0.56,
          ),
          itemBuilder: (context, index) {
            var reel = savedReels[index].data() as Map<String, dynamic>;
            return GestureDetector(
              // 🌟 మ్యాజిక్: ScrollingReelsScreen కి కనెక్ట్ చేసాం
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ScrollingReelsScreen(
                    reelIds: reelIds,
                    initialIndex: index,
                  ),
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Colors.grey[900],
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        color: Colors.white54,
                        size: 30,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 5,
                    left: 5,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.play_arrow_outlined,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          "${reel['likes']?.length ?? 0}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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

  Widget _buildPostGrid(
    Stream<QuerySnapshot> stream, {
    bool shrinkWrap = false,
    ScrollPhysics? physics,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        var posts = snapshot.data?.docs ?? [];
        if (posts.isEmpty) return const Center(child: Text("No posts found."));
        List<String> postIds = posts.map((doc) => doc.id).toList();

        return GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: shrinkWrap,
          physics: physics ?? const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
          ),
          itemCount: posts.length,
          itemBuilder: (context, i) {
            var postData = posts[i].data() as Map<String, dynamic>;
            String thumbnail =
                (postData['postData'] is List &&
                    (postData['postData'] as List).isNotEmpty)
                ? postData['postData'][0].toString()
                : postData['postData']?.toString() ?? "";
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ScrollingPostsScreen(postIds: postIds, initialIndex: i),
                ),
              ),
              child: SafeImage(base64String: thumbnail),
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
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          num,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar, this._color);
  final TabBar _tabBar;
  final Color _color;
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Container(color: _color, child: _tabBar);
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
