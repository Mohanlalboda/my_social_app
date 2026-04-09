// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../utils/constants.dart';
import '../../services/upload_manager.dart';
import '../../services/paginated_grid.dart';
import '../create/add_post_screen.dart';
import '../../widgets/safe_elements.dart';
import 'user_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  // 🌟 THE GHOST CLEANUP FUNCTION (బ్యాక్‌గ్రౌండ్ లో రన్ అవుతుంది)
  Future<void> _cleanGhostUsers(
    List currentFollowers,
    List currentFollowing,
  ) async {
    List<String> validFollowers = [];
    List<String> validFollowing = [];
    bool needsUpdate = false;

    for (String id in currentFollowers) {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(id)
          .get();
      if (doc.exists) {
        validFollowers.add(id);
      } else {
        needsUpdate = true;
      }
    }

    for (String id in currentFollowing) {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(id)
          .get();
      if (doc.exists) {
        validFollowing.add(id);
      } else {
        needsUpdate = true;
      }
    }

    if (needsUpdate) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'followers': validFollowers,
        'following': validFollowing,
      });
    }
  }

  // ⚙️ Settings
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
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: Text(
                "Settings and privacy",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            const Divider(),
            SwitchListTile(
              secondary: const Icon(Icons.lock_outline),
              title: Text(
                "Private Account",
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              value: currentPrivateStatus,
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

  // 📷 Profile Pic Action
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

  // 🍔 Menu
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
              leading: Icon(
                Icons.settings_outlined,
                color: isDark ? Colors.white : Colors.black,
              ),
              title: Text(
                "Settings and privacy",
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
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

  // 📝 Edit Profile
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
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 🖼️ Update Profile Pic
  Future<void> _updateProfilePic() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image != null) {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Picture',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            cropStyle: CropStyle.circle,
          ),
          IOSUiSettings(
            title: 'Crop Profile Picture',
            cropStyle: CropStyle.circle,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
        ],
      );
      if (croppedFile != null) {
        _backgroundUploadProfilePic(File(croppedFile.path));
      }
    }
  }

  Future<void> _backgroundUploadProfilePic(File file) async {
    UploadManager().isUploading.value = true;
    UploadManager().uploadProgress.value = 0.0;
    UploadManager().uploadStatus.value = "Updating Profile Picture...";
    try {
      var storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pics')
          .child('$uid.jpg');
      UploadTask uploadTask = storageRef.putFile(file);
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        UploadManager().uploadProgress.value =
            snapshot.bytesTransferred / snapshot.totalBytes;
      });
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        "profilePic": downloadUrl,
      });
    } catch (e) {
      debugPrint("Profile Pic Upload Error: $e");
    } finally {
      UploadManager().isUploading.value = false;
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
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var userData =
              userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          String name = userData['username'] ?? "User";
          String bio = userData['bio'] ?? "";
          bool isPrivate = userData['isPrivate'] ?? false;
          List followers = userData['followers'] ?? [];
          List following = userData['following'] ?? [];

          // 🌟 THE FIX: ఇక్కడ స్కాన్ రన్ అవుతుంది, దెయ్యాలు ఉంటే ఎగిరిపోతాయి!
          _cleanGhostUsers(followers, following);

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
                  icon: Icon(
                    Icons.add_box_outlined,
                    size: 28,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddPostScreen()),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.menu,
                    size: 28,
                    color: isDark ? Colors.white : Colors.black,
                  ),
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
                                decoration: const BoxDecoration(
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
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            if (bio.isNotEmpty)
                              Text(
                                bio,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),
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
                  PaginatedGrid(
                    query: FirebaseFirestore.instance
                        .collection('posts')
                        .where('ownerId', isEqualTo: uid)
                        .where('type', isEqualTo: 'image'),
                  ),
                  PaginatedGrid(
                    query: FirebaseFirestore.instance
                        .collection('posts')
                        .where('ownerId', isEqualTo: uid)
                        .where('type', isEqualTo: 'video'),
                    isReel: true,
                  ),
                  _buildSavedTab(uid, isDark),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSavedTab(String uid, bool isDark) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            "📌 Saved Posts",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
        PaginatedGrid(
          query: FirebaseFirestore.instance
              .collection('posts')
              .where('savedBy', arrayContains: uid)
              .where('type', isEqualTo: 'image'),
          isScrollable: false,
        ),
        const Divider(height: 30),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            "🎬 Saved Reels",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
        PaginatedGrid(
          query: FirebaseFirestore.instance
              .collection('posts')
              .where('savedBy', arrayContains: uid)
              .where('type', isEqualTo: 'video'),
          isReel: true,
          isScrollable: false,
        ),
      ],
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String num, label;
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
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    );
  }
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
