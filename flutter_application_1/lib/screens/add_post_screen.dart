// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  // 🌟 Post Variables
  List<File> _selectedImages = [];
  final TextEditingController _postCaptionController = TextEditingController();
  bool _isUploadingPost = false;
  bool _isPostPublic = true;

  // 🌟 Reel Variables
  File? _selectedVideo;
  final TextEditingController _reelCaptionController = TextEditingController();
  bool _isUploadingReel = false;
  bool _isReelPublic = true;

  // 🌟 Pick Multiple Images for Post
  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 50);

    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedImages = pickedFiles.map((file) => File(file.path)).toList();
      });
    }
  }

  // 🌟 Pick Video for Reel
  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedVideo = File(pickedFile.path));
    }
  }

  // 🌟 Upload Post with Multiple Images to Firebase Storage
  Future<void> _uploadPost() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one image! 📸")),
      );
      return;
    }
    setState(() => _isUploadingPost = true);

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      String username = userDoc.data()?['username'] ?? 'User';
      String profilePic = userDoc.data()?['profilePic'] ?? '';

      List<String> imageUrls = [];
      for (var file in _selectedImages) {
        String imageId = const Uuid().v4();
        Reference ref = FirebaseStorage.instance
            .ref()
            .child('posts')
            .child(uid)
            .child(imageId);
        UploadTask uploadTask = ref.putFile(file);
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();
        imageUrls.add(downloadUrl);
      }

      String postId = const Uuid().v4();

      await FirebaseFirestore.instance.collection('posts').doc(postId).set({
        'postId': postId,
        'ownerId': uid,
        'username': username,
        'profilePic': profilePic,
        'postData': imageUrls, // 🌟 Saving URLs instead of Base64
        'caption': _postCaptionController.text.trim(),
        'likes': [],
        'savedBy': [],
        'isPublic': _isPostPublic,
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _selectedImages.clear();
        _postCaptionController.clear();
        _isPostPublic = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Post uploaded successfully! ✅"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Post Upload Error: $e");
    }

    if (mounted) {
      setState(() => _isUploadingPost = false);
    }
  }

  // 🌟 Upload Reel to Firebase Storage
  Future<void> _uploadReel() async {
    if (_selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a video from gallery! 🎬")),
      );
      return;
    }
    setState(() => _isUploadingReel = true);

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      String username = userDoc.data()?['username'] ?? 'User';
      String profilePic = userDoc.data()?['profilePic'] ?? '';
      String reelId = const Uuid().v4();

      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('reels')
          .child('$reelId.mp4');
      UploadTask uploadTask = storageRef.putFile(_selectedVideo!);
      TaskSnapshot snapshot = await uploadTask;
      String videoUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('reels').doc(reelId).set({
        'reelId': reelId,
        'uid': uid,
        'username': username,
        'profilePic': profilePic,
        'videoUrl': videoUrl,
        'caption': _reelCaptionController.text.trim(),
        'likes': [],
        'savedBy': [],
        'isPublic': _isReelPublic,
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _selectedVideo = null;
        _reelCaptionController.clear();
        _isReelPublic = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Reel uploaded successfully! 🎬✅"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Reel Upload Error: $e");
    }

    if (mounted) {
      setState(() => _isUploadingReel = false);
    }
  }

  @override
  void dispose() {
    _postCaptionController.dispose();
    _reelCaptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "New Post",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.blue,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.grid_on), text: "POST"),
              Tab(icon: Icon(Icons.video_library), text: "REEL"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 🌟 POST TAB
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      height: 300,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: _selectedImages.isNotEmpty
                          ? Stack(
                              children: [
                                PageView.builder(
                                  itemCount: _selectedImages.length,
                                  itemBuilder: (context, index) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: Image.file(
                                        _selectedImages[index],
                                        fit: BoxFit.cover,
                                      ),
                                    );
                                  },
                                ),
                                if (_selectedImages.length > 1)
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.7,
                                        ),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Text(
                                        "${_selectedImages.length} Photos",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  bottom: 10,
                                  right: 10,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.white,
                                      ),
                                      onPressed: _pickImages,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  "Tap to select multiple photos",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _postCaptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: "Write a caption...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 15),
                  SwitchListTile(
                    title: const Text("Make this post Public"),
                    value: _isPostPublic,
                    activeThumbColor: Colors.white,
                    activeTrackColor: Colors.blue,
                    onChanged: (bool value) =>
                        setState(() => _isPostPublic = value),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isUploadingPost ? null : _uploadPost,
                      child: _isUploadingPost
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Share Post",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),

            // 🌟 REEL TAB
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickVideo,
                    child: Container(
                      height: 300,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: _selectedVideo != null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 60,
                                  color: Colors.green,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  "Video Selected! Ready to upload.",
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.video_collection,
                                  size: 50,
                                  color: Colors.blue,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  "Tap to select a video from gallery",
                                  style: TextStyle(color: Colors.blue),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _reelCaptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: "Write a caption for your Reel...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 15),
                  SwitchListTile(
                    title: const Text("Make this post Public"),
                    value: _isReelPublic,
                    activeThumbColor: Colors.white,
                    activeTrackColor: Colors.blue,
                    onChanged: (bool value) =>
                        setState(() => _isReelPublic = value),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isUploadingReel ? null : _uploadReel,
                      child: _isUploadingReel
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Share Reel",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
