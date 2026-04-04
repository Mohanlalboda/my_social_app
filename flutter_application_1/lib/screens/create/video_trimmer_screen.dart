// ignore_for_file: use_build_context_synchronously, depend_on_referenced_packages

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_trimmer/video_trimmer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';

import 'add_post_screen.dart'; // 🌟 UploadManager కోసం దీన్ని ఇంపోర్ట్ చేశాం

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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFD1D1D),
            ),
            onPressed: () => Navigator.pop(ctx, captionCtrl.text.trim()),
            child: const Text(
              "Share Story",
              style: TextStyle(color: Colors.white),
            ),
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
    if (caption == null) return;

    // 🌟 మ్యాజిక్: అప్‌లోడ్ మేనేజర్‌కి డేటా ఇచ్చేసి స్క్రీన్ ని వెంటనే పాప్ చేస్తాం (మాయం)
    UploadManager().isUploading.value = true;
    UploadManager().uploadProgress.value = 0.1; // స్టార్టింగ్ ప్రోగ్రెస్
    UploadManager().uploadStatus.value = "Trimming video... ✂️";

    Navigator.of(context).pop(); // 🌟 ఇక్కడ స్క్రీన్ మాయం అయిపోతుంది

    try {
      await _trimmer.saveTrimmedVideo(
        startValue: _startValue,
        endValue: _endValue,
        videoFileName: "story_trim_${DateTime.now().millisecondsSinceEpoch}",
        storageDir: StorageDir.temporaryDirectory,
        onSave: (String? outputPath) async {
          if (outputPath == null) {
            UploadManager().isUploading.value = false;
            return;
          }

          // 🌟 కట్ అవ్వగానే బ్యాక్‌గ్రౌండ్ లో కంప్రెసింగ్ స్టార్ట్ అవుతుంది
          try {
            UploadManager().uploadStatus.value = "Compressing... ⚡";
            UploadManager().uploadProgress.value = 0.3;

            File fileToUpload = File(outputPath);
            MediaInfo? info = await VideoCompress.compressVideo(
              outputPath,
              quality: VideoQuality.MediumQuality,
              includeAudio: true,
            );

            if (info != null && info.file != null) {
              fileToUpload = info.file!;
            }

            UploadManager().uploadStatus.value = "Uploading to Cloud... ☁️";
            UploadManager().uploadProgress.value = 0.4;

            String storyId = const Uuid().v4();
            Reference ref = FirebaseStorage.instance
                .ref()
                .child('stories')
                .child(currentUid)
                .child('$storyId.mp4');

            UploadTask uploadTask = ref.putFile(fileToUpload);

            // 🌟 ప్రోగ్రెస్ బార్ అప్‌డేట్
            uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
              double p = snapshot.bytesTransferred / snapshot.totalBytes;
              UploadManager().uploadProgress.value =
                  0.4 + (p * 0.5); // 40% నుండి 90% వరకు
              UploadManager().uploadStatus.value =
                  "Uploading Story... ${(p * 100).toInt()}%";
            });

            await uploadTask;
            String downloadUrl = await ref.getDownloadURL();

            UploadManager().uploadStatus.value = "Finishing up...";
            UploadManager().uploadProgress.value = 0.95;

            // 🌟 ఫైర్‌బేస్ లో సేవ్ చేయడం
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
          } catch (e) {
            debugPrint("Background Trimmer Upload Error: $e");
          } finally {
            VideoCompress.deleteAllCache();
            UploadManager().isUploading.value =
                false; // 🌟 పూర్తయ్యాక బార్ మాయం
          }
        },
      );
    } catch (e) {
      debugPrint("Trimmer save error: $e");
      UploadManager().isUploading.value = false;
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
                      onChangeStart: (value) => _startValue = value,
                      onChangeEnd: (value) => _endValue = value,
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
          // 🌟 పాత ఫుల్-స్క్రీన్ లోడింగ్ స్పిన్నర్ ని పీకేసాం! (No more blocking screen)
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
