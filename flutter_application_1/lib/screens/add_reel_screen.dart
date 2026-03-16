// ignore_for_file: unused_import

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../services/firestore_methods.dart'; // మనం ఇందాక క్రియేట్ చేసిన ఫైల్

class AddReelScreen extends StatefulWidget {
  const AddReelScreen({super.key});

  @override
  State<AddReelScreen> createState() => _AddReelScreenState();
}

class _AddReelScreenState extends State<AddReelScreen> {
  File? _video;
  final TextEditingController _captionController = TextEditingController();
  VideoPlayerController? _videoController;
  bool _isLoading = false;

  // 🎥 గ్యాలరీ నుండి వీడియో సెలెక్ట్ చేసే ఫంక్షన్
  // 🎥 ఫైల్ మేనేజర్ నుండి వీడియో సెలెక్ట్ చేసే ఫంక్షన్
  void _selectVideo() async {
    try {
      // ఇక్కడ file_picker వాడుతున్నాం, ఇది పక్కాగా వీడియోలనే చూపిస్తుంది
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video, // 🌟 కేవలం వీడియోలు మాత్రమే కనిపించేలా సెట్ చేశాం
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _video = File(result.files.single.path!);
        });

        // పాత ప్లేయర్ ఉంటే క్లియర్ చేసి కొత్తది పెడుతున్నాం
        _videoController?.dispose();
        _videoController = VideoPlayerController.file(_video!)
          ..initialize()
              .then((_) {
                setState(() {});
                _videoController!.play();
                _videoController!.setLooping(true);
              })
              .catchError((e) {
                debugPrint("🎥 Player Error: $e");
                return null;
              });
      } else {
        debugPrint("❌ User canceled video selection.");
      }
    } catch (e) {
      debugPrint("🚨 File Picker Error: $e");
    }
  } // 👈 '_selectVideo' ఫంక్షన్ ఇక్కడ క్లోజ్ అవుతుంది

  // 🚀 వీడియోని అప్‌లోడ్ చేసే ఫంక్షన్
  void _uploadReel() async {
    if (_video == null) return;

    setState(() {
      _isLoading = true;
    });

    String res = await ReelService().postReel(_captionController.text, _video!);

    setState(() {
      _isLoading = false;
    });

    if (res == "success") {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reel Posted Successfully! 🎬")),
        );
        Navigator.pop(context); // అప్‌లోడ్ అయ్యాక బ్యాక్ వెళ్ళిపోతుంది
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $res")));
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Reel"),
        backgroundColor: Colors.black,
        actions: [
          TextButton(
            onPressed: _uploadReel,
            child: const Text(
              "Share",
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
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text("Uploading Reel... Please wait! 📽️"),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // 📺 వీడియో ప్రివ్యూ లేదా వీడియో సెలెక్ట్ చేసే బటన్
                  Center(
                    child: _video == null
                        ? InkWell(
                            onTap: _selectVideo,
                            child: Container(
                              height: 200,
                              width: 200,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                              ),
                              child: const Icon(Icons.add_a_photo, size: 50),
                            ),
                          )
                        : SizedBox(
                            // 🌟 Container బదులు SizedBox వాడండి
                            height: 300,
                            width: MediaQuery.of(context).size.width * 0.8,
                            child:
                                _videoController != null &&
                                    _videoController!.value.isInitialized
                                ? AspectRatio(
                                    aspectRatio:
                                        _videoController!.value.aspectRatio,
                                    child: VideoPlayer(_videoController!),
                                  )
                                : const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                          ),
                  ),
                  const SizedBox(height: 20),
                  // ✍️ క్యాప్షన్ బాక్స్
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: TextField(
                      controller: _captionController,
                      decoration: const InputDecoration(
                        hintText: "Write a caption...",
                        border: InputBorder.none,
                      ),
                      maxLines: 3,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
