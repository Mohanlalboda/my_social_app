// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';

class UploadMediaScreen extends StatefulWidget {
  final String filePath;
  final bool isVideo;

  const UploadMediaScreen({
    super.key,
    required this.filePath,
    required this.isVideo,
  });

  @override
  State<UploadMediaScreen> createState() => _UploadMediaScreenState();
}

class _UploadMediaScreenState extends State<UploadMediaScreen> {
  final TextEditingController _captionController = TextEditingController();
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  
  VideoPlayerController? _videoController;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _videoController = VideoPlayerController.file(File(widget.filePath))
        ..initialize().then((_) {
          setState(() {});
          _videoController!.setLooping(true);
          _videoController!.play();
        });
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // 🌟 అప్‌లోడ్ మ్యాజిక్ ఇక్కడే జరుగుతుంది
  Future<void> _uploadMedia() async {
    setState(() => _isUploading = true);

    try {
      String ext = widget.isVideo ? "mp4" : "jpg";
      String fileName = "${DateTime.now().millisecondsSinceEpoch}.$ext";
      String folderName = widget.isVideo ? "reels_media" : "posts_media";
      
      // 1. Firebase Storage లోకి ఫైల్ పంపడం
      Reference ref = FirebaseStorage.instance.ref().child(folderName).child(fileName);
      UploadTask uploadTask = ref.putFile(File(widget.filePath));
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // 2. Firestore Database లో డేటా సేవ్ చేయడం
      String collectionName = widget.isVideo ? "reels" : "posts";
      
      await FirebaseFirestore.instance.collection(collectionName).add({
        'ownerId': currentUid,
        'mediaUrl': downloadUrl,
        'description': _captionController.text.trim(),
        'type': widget.isVideo ? 'video' : 'image',
        'likes': [],
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 3. సక్సెస్ అయ్యాక హోమ్ స్క్రీన్ కి పంపించడం
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Uploaded Successfully! 🚀")),
        );
        // హోమ్ స్క్రీన్ కి వెళ్లడానికి (కెమెరా స్క్రీన్, క్రియేట్ స్క్రీన్ రెండూ క్లోజ్ అవుతాయి)
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      debugPrint("Upload Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload Failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: const Text("New Post"),
        backgroundColor: isDark ? Colors.black : Colors.white,
        actions: [
          _isUploading
              ? const Padding(
                  padding: EdgeInsets.all(15.0),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.blue, strokeWidth: 2)),
                )
              : TextButton(
                  onPressed: _uploadMedia,
                  child: const Text("Share", style: TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_isUploading) const LinearProgressIndicator(color: Colors.blue),
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ప్రివ్యూ బాక్స్ (Photo / Video)
                  Container(
                    height: 100,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: widget.isVideo
                        ? (_videoController != null && _videoController!.value.isInitialized
                            ? FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _videoController!.value.size.width,
                                  height: _videoController!.value.size.height,
                                  child: VideoPlayer(_videoController!),
                                ),
                              )
                            : const Center(child: CircularProgressIndicator()))
                        : Image.file(File(widget.filePath), fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 15),
                  // క్యాప్షన్ (Caption) టెక్స్ట్ ఫీల్డ్
                  Expanded(
                    child: TextField(
                      controller: _captionController,
                      maxLines: 4,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: const InputDecoration(
                        hintText: "Write a caption...",
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text("Add Location"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 15),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.person_add_outlined),
              title: const Text("Tag People"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 15),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}