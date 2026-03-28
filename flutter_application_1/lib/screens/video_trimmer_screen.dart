// ignore_for_file: use_build_context_synchronously, depend_on_referenced_packages

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_trimmer/video_trimmer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';

class VideoTrimmerScreen extends StatefulWidget {
  final File file;
  final Map<String, dynamic> userData;

  const VideoTrimmerScreen({
    super.key,
    required this.file,
    required this.userData,
  });

  @override
  State<VideoTrimmerScreen> createState() => _VideoTrimmerScreenState();
}

class _VideoTrimmerScreenState extends State<VideoTrimmerScreen> {
  final Trimmer _trimmer = Trimmer();
  double _startValue = 0.0;
  double _endValue = 0.0;
  bool _isPlaying = false;
  bool _progressVisibility = false;
  String _progressText = "Trimming video...";
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  void _loadVideo() {
    _trimmer.loadVideo(videoFile: widget.file);
  }

  Future<String?> _askForCaption() async {
    TextEditingController captionCtrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Caption"),
        content: TextField(
          controller: captionCtrl,
          decoration: const InputDecoration(
            hintText: "Write a caption for your story...",
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, captionCtrl.text.trim()),
            child: const Text("Share Story"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveVideo() async {
    if (_endValue == 0.0) {
      double totalDuration =
          _trimmer.videoPlayerController?.value.duration.inMilliseconds
              .toDouble() ??
          0.0;
      _endValue = totalDuration > 30000.0 ? 30000.0 : totalDuration;
    }

    if (_startValue >= _endValue || _endValue == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a valid video part! ❌"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String? caption = await _askForCaption();
    if (caption == null) {
      return; // 🌟 ఫ్లవర్ బ్రాకెట్స్ యాడ్ చేశాం!
    }

    setState(() {
      _progressVisibility = true;
      _progressText = "Cutting video... ✂️";
    });

    try {
      await _trimmer.saveTrimmedVideo(
        startValue: _startValue,
        endValue: _endValue,
        videoFileName: "story_trim_${DateTime.now().millisecondsSinceEpoch}",
        storageDir: StorageDir.temporaryDirectory,
        onSave: (String? outputPath) async {
          if (outputPath == null) {
            if (mounted) {
              setState(() {
                _progressVisibility = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Error: Trimmer failed (Video format might not be supported) ❌",
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }

          try {
            File fileToUpload = File(outputPath);

            if (mounted) {
              setState(() {
                _progressText = "Compressing for fast upload... ⚡";
              });
            } // 🌟 ఫ్లవర్ బ్రాకెట్స్ యాడ్ చేశాం!

            MediaInfo? info = await VideoCompress.compressVideo(
              outputPath,
              quality: VideoQuality.MediumQuality,
              includeAudio: true,
            );

            if (info != null && info.file != null) {
              fileToUpload = info.file!;
            }

            if (mounted) {
              setState(() {
                _progressText = "Uploading to Cloud... ☁️";
              });
            } // 🌟 ఫ్లవర్ బ్రాకెట్స్ యాడ్ చేశాం!

            String storyId = const Uuid().v4();
            Reference ref = FirebaseStorage.instance
                .ref()
                .child('stories')
                .child(currentUid)
                .child('$storyId.mp4');

            await ref.putFile(fileToUpload);
            String downloadUrl = await ref.getDownloadURL();

            await FirebaseFirestore.instance.collection('stories').add({
              "uid": currentUid,
              "ownerId": currentUid,
              "username": widget.userData['username'] ?? "User",
              "profilePic": widget.userData['profilePic'] ?? "",
              "storyUrl": downloadUrl,
              "type": "video",
              "caption": caption,
              "timestamp": FieldValue.serverTimestamp(),
              "viewers": [],
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Story Uploaded Successfully! ✅"),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.of(context).pop();
            }
          } catch (e) {
            debugPrint("Trim Upload Error: $e");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Upload Error: $e"),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } finally {
            VideoCompress.deleteAllCache();
            if (mounted) {
              setState(() {
                _progressVisibility = false;
              });
            } // 🌟 ఫ్లవర్ బ్రాకెట్స్ యాడ్ చేశాం!
          }
        },
      );
    } catch (e) {
      debugPrint("Trimmer save error: $e");
      if (mounted) {
        setState(() {
          _progressVisibility = false;
        }); // 🌟 ఫ్లవర్ బ్రాకెట్స్ యాడ్ చేశాం!

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Exact Error: ${e.toString()}"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Trim Video (Max 30s)"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (!_progressVisibility)
            TextButton(
              onPressed: _saveVideo,
              child: const Text(
                "Done",
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.only(bottom: 30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  Expanded(child: VideoViewer(trimmer: _trimmer)),
                  Center(
                    child: TrimViewer(
                      trimmer: _trimmer,
                      viewerHeight: 50.0,
                      viewerWidth: MediaQuery.of(context).size.width,
                      maxVideoLength: const Duration(seconds: 30),
                      onChangeStart: (value) {
                        _startValue = value;
                      },
                      onChangeEnd: (value) {
                        _endValue = value;
                      },
                      onChangePlaybackState: (value) {
                        setState(() {
                          _isPlaying = value;
                        });
                      },
                    ),
                  ),
                  TextButton(
                    child: _isPlaying
                        ? const Icon(Icons.pause, size: 40, color: Colors.white)
                        : const Icon(
                            Icons.play_arrow,
                            size: 40,
                            color: Colors.white,
                          ),
                    onPressed: () async {
                      bool playbackState = await _trimmer.videoPlaybackControl(
                        startValue: _startValue,
                        endValue: _endValue,
                      );
                      setState(() {
                        _isPlaying = playbackState;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          if (_progressVisibility)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.blue),
                    const SizedBox(height: 20),
                    Text(
                      _progressText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _trimmer.dispose();
    super.dispose();
  }
}
