import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// 🌟 కొత్త సింటాక్స్ కోసం ఈ రెండు ఇంపోర్ట్స్ కచ్చితంగా ఉండాలి
import 'package:video_player/video_player.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import '../../services/firestore_methods.dart';

class AddReelScreen extends StatefulWidget {
  const AddReelScreen({super.key});

  @override
  State<AddReelScreen> createState() => _AddReelScreenState();
}

class _AddReelScreenState extends State<AddReelScreen> {
  File? _videoFile;
  CachedVideoPlayerPlus? _videoPlayer;
  final TextEditingController _captionController = TextEditingController();
  bool _isLoading = false;

  Future<void> _selectVideo() async {
    final pickedFile = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      File video = File(pickedFile.path);

      _videoPlayer?.dispose();

      _videoPlayer = CachedVideoPlayerPlus.file(video)
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {
            _videoFile = video;
          });
          _videoPlayer?.controller.play();
          _videoPlayer?.controller.setLooping(true);
        });
    }
  }

  void _uploadReel() async {
    if (_videoFile == null || _captionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a video and write a caption! ⚠️"),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // 🌟 ఆప్టిమైజేషన్: FirestoreMethods లో ఉన్న కంప్రెషన్ లాజిక్ రన్ అవుతుంది.
    // కాబట్టి మనం ఇక్కడ డైరెక్ట్ ఫైల్ పంపినా సరిపోతుంది.
    String res = await FirestoreMethods().uploadReel(
      _captionController.text.trim(),
      _videoFile!,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (res == "success") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Reel uploaded successfully! 🎉"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $res"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  void dispose() {
    _videoPlayer?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        title: const Text(
          'Add Reel',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_videoFile != null)
            TextButton(
              onPressed: _isLoading ? null : _uploadReel,
              child: const Text(
                'Share',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.blueAccent),
                  const SizedBox(height: 15),
                  Text(
                    "Compressing & Uploading your Reel... 🍿",
                    style: TextStyle(
                      color: isDark ? Colors.grey : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            )
          : _videoFile == null
          ? Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                ),
                onPressed: _selectVideo,
                icon: const Icon(Icons.video_library, color: Colors.white),
                label: const Text(
                  "Select Video from Gallery",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _videoPlayer != null && _videoPlayer!.isInitialized
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AspectRatio(
                              aspectRatio:
                                  _videoPlayer!.controller.value.aspectRatio,
                              child: SizedBox(
                                height: 300,
                                child: VideoPlayer(_videoPlayer!.controller),
                              ),
                            ),
                          )
                        : const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _captionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: "Write a catchy caption...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
