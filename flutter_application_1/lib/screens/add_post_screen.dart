import 'dart:io';
import 'dart:convert';
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
  File? _selectedImage;
  final TextEditingController _postCaptionController = TextEditingController();
  bool _isUploadingPost = false;
  bool _isPostPublic = true;

  File? _selectedVideo;
  final TextEditingController _reelCaptionController = TextEditingController();
  bool _isUploadingReel = false;
  bool _isReelPublic = true;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) setState(() => _selectedImage = File(pickedFile.path));
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) setState(() => _selectedVideo = File(pickedFile.path));
  }

  Future<void> _uploadPost() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select an image! 📸")));
      return;
    }
    setState(() => _isUploadingPost = true);

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      String username = userDoc.data()?['username'] ?? 'User';
      String profilePic = userDoc.data()?['profilePic'] ?? '';

      String base64Image = base64Encode(await _selectedImage!.readAsBytes());
      String postId = const Uuid().v4();

      await FirebaseFirestore.instance.collection('posts').doc(postId).set({
        'postId': postId,
        'ownerId': uid,
        'username': username,
        'profilePic': profilePic,
        'postData': base64Image,
        'caption': _postCaptionController.text.trim(),
        'likes': [],
        'savedBy': [],
        'isPublic': _isPostPublic,
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _selectedImage = null;
        _postCaptionController.clear();
        _isPostPublic = true;
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post uploaded successfully! ✅"), backgroundColor: Colors.green));
    } catch (e) {
      debugPrint("Post Upload Error: $e");
    }
    if (mounted) setState(() => _isUploadingPost = false);
  }

  Future<void> _uploadReel() async {
    if (_selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a video from gallery! 🎬")));
      return;
    }
    setState(() => _isUploadingReel = true);

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      String username = userDoc.data()?['username'] ?? 'User';
      String profilePic = userDoc.data()?['profilePic'] ?? '';
      String reelId = const Uuid().v4();

      Reference storageRef = FirebaseStorage.instance.ref().child('reels').child('$reelId.mp4');
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

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reel uploaded successfully! 🎬✅"), backgroundColor: Colors.green));
    } catch (e) {
      debugPrint("Reel Upload Error: $e");
    }
    if (mounted) setState(() => _isUploadingReel = false);
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
          title: const Text("New Post", style: TextStyle(fontWeight: FontWeight.bold)),
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
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 300,
                      width: double.infinity,
                      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade300)),
                      child: _selectedImage != null
                          ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(_selectedImage!, fit: BoxFit.cover))
                          : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, size: 50, color: Colors.grey), SizedBox(height: 10), Text("Tap to select photo", style: TextStyle(color: Colors.grey))]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(controller: _postCaptionController, maxLines: 3, decoration: InputDecoration(hintText: "Write a caption...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true)),
                  const SizedBox(height: 15),
                  SwitchListTile(
                    title: const Text("Make this post Public"),
                    value: _isPostPublic,
                    activeThumbColor: Colors.white,
                    activeTrackColor: Colors.blue,
                    onChanged: (bool value) => setState(() => _isPostPublic = value),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: _isUploadingPost ? null : _uploadPost,
                      child: _isUploadingPost ? const CircularProgressIndicator(color: Colors.white) : const Text("Share Post", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickVideo,
                    child: Container(
                      height: 300,
                      width: double.infinity,
                      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blue.shade200)),
                      child: _selectedVideo != null
                          ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle, size: 60, color: Colors.green), SizedBox(height: 10), Text("Video Selected! Ready to upload.", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))])
                          : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.video_collection, size: 50, color: Colors.blue), SizedBox(height: 10), Text("Tap to select a video from gallery", style: TextStyle(color: Colors.blue))]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(controller: _reelCaptionController, maxLines: 3, decoration: InputDecoration(hintText: "Write a caption for your Reel...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true)),
                  const SizedBox(height: 15),
                  SwitchListTile(
                    title: const Text("Make this post Public"),
                    value: _isPostPublic,
                    activeThumbColor: Colors.white,
                    activeTrackColor: Colors.blue,
                    onChanged: (bool value) => setState(() => _isPostPublic = value),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: _isUploadingReel ? null : _uploadReel,
                      child: _isUploadingReel ? const CircularProgressIndicator(color: Colors.white) : const Text("Share Reel", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
