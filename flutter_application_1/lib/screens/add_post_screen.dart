// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

// 🌟 కొత్తగా యాడ్ చేసిన కంప్రెషన్ ప్యాకేజీలు
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';

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
    final pickedFiles = await picker.pickMultiImage(
      imageQuality: 100,
    ); // కంప్రెషన్ కింద చేస్తాం కాబట్టి ఇక్కడ 100 ఇవ్వొచ్చు

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

  // 🌟 Upload Post with Multiple Images (Compression Added)
  Future<void> _uploadPost() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one image! 📸")),
      );
      return;
    }
    setState(() => _isUploadingPost = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Compressing & Uploading Images... ⏳")),
    );

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      String username = userDoc.data()?['username'] ?? 'User';
      String profilePic = userDoc.data()?['profilePic'] ?? '';

      List<String> imageUrls = [];
      final tempDir = await getTemporaryDirectory();

      for (var file in _selectedImages) {
        String imageId = const Uuid().v4();

        // 📸 1. IMAGE COMPRESSION (70% Quality for Posts)
        final outPath = "${tempDir.path}/post_$imageId.jpg";
        var compressedImage = await FlutterImageCompress.compressAndGetFile(
          file.path,
          outPath,
          quality: 70, // పోస్ట్‌లు కాబట్టి క్వాలిటీ 70% ఉంచాం
          minWidth: 1080,
          minHeight: 1080,
        );

        File fileToUpload = compressedImage != null
            ? File(compressedImage.path)
            : file;

        Reference ref = FirebaseStorage.instance
            .ref()
            .child('posts')
            .child(uid)
            .child('$imageId.jpg');
        UploadTask uploadTask = ref.putFile(fileToUpload);
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
        'postData': imageUrls,
        'type': 'image',
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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Upload Error: $e",
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) setState(() => _isUploadingPost = false);
    }
  }

  // 🌟 Upload Reel with Video Compression
  Future<void> _uploadReel() async {
    if (_selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a video from gallery! 🎬")),
      );
      return;
    }
    setState(() => _isUploadingReel = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Compressing Video... Please wait ⏳")),
    );

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      String username = userDoc.data()?['username'] ?? 'User';
      String profilePic = userDoc.data()?['profilePic'] ?? '';

      String postId = const Uuid().v4();

      // 🎥 2. VIDEO COMPRESSION
      MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        _selectedVideo!.path,
        quality: VideoQuality.MediumQuality,
        includeAudio: true,
      );

      File fileToUpload = (mediaInfo != null && mediaInfo.file != null)
          ? mediaInfo.file!
          : _selectedVideo!;

      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('reels')
          .child('$postId.mp4');
      UploadTask uploadTask = storageRef.putFile(fileToUpload);
      TaskSnapshot snapshot = await uploadTask;
      String videoUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('posts').doc(postId).set({
        'postId': postId,
        'ownerId': uid,
        'username': username,
        'profilePic': profilePic,
        'postData': [videoUrl],
        'storyUrl': videoUrl,
        'type': 'video',
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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Upload Error: $e",
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      VideoCompress.deleteAllCache(); // 🌟 అప్‌లోడ్ అయ్యాక చెత్త క్లీన్ చేయాలి
      if (mounted) setState(() => _isUploadingReel = false);
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
        body: TabBarView(children: [_buildPostTab(), _buildReelTab()]),
      ),
    );
  }

  Widget _buildPostTab() {
    return SingleChildScrollView(
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
                  ? PageView.builder(
                      itemCount: _selectedImages.length,
                      itemBuilder: (ctx, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(
                          _selectedImages[i],
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.add_photo_alternate,
                        size: 50,
                        color: Colors.grey,
                      ),
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
            ),
          ),
          SwitchListTile(
            title: const Text("Public Post"),
            value: _isPostPublic,
            onChanged: (v) => setState(() => _isPostPublic = v),
          ),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: _isUploadingPost ? null : _uploadPost,
              child: _isUploadingPost
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          "Processing...",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      "Share Post",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReelTab() {
    return SingleChildScrollView(
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
                  ? const Center(
                      child: Icon(
                        Icons.check_circle,
                        size: 60,
                        color: Colors.green,
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.video_collection,
                        size: 50,
                        color: Colors.blue,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _reelCaptionController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Reel caption...",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          SwitchListTile(
            title: const Text("Public Reel"),
            value: _isReelPublic,
            onChanged: (v) => setState(() => _isReelPublic = v),
          ),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
              onPressed: _isUploadingReel ? null : _uploadReel,
              child: _isUploadingReel
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          "Compressing...",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      "Share Reel",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
