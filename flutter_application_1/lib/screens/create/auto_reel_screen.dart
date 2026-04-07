// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/upload_manager.dart'; // 🌟 UploadManager కోసం

class AutoReelScreen extends StatefulWidget {
  const AutoReelScreen({super.key});

  @override
  State<AutoReelScreen> createState() => _AutoReelScreenState();
}

class _AutoReelScreenState extends State<AutoReelScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<File> _selectedImages = [];
  int _currentIndex = 0;
  Timer? _timer;
  bool _isPlaying = false;
  int _elapsedSeconds = 0;
  final int _maxSeconds = 60;
  final TextEditingController _captionController = TextEditingController();

  bool _isLocalAudio = false;
  String? _localAudioPath;
  String _audioName = "Trending Audio 🎵";

  final String trendingMusicUrl =
      "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3";

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 80);
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedImages = pickedFiles.map((x) => File(x.path)).toList();
        _currentIndex = 0;
        _elapsedSeconds = 0;
      });
      _startMagicReel();
    }
  }

  void _showMusicPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.whatshot, color: Colors.red),
              title: const Text("App Trending Music"),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _isLocalAudio = false;
                  _audioName = "Trending Audio 🎵";
                });
                _startMagicReel();
              },
            ),
            ListTile(
              leading: const Icon(Icons.library_music, color: Colors.blue),
              title: const Text(
                "Pick from My Phone",
              ), // 🌟 "Cut" అనే మాట తీసేశాం
              onTap: () async {
                Navigator.pop(ctx);
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.audio,
                );

                if (result != null && result.files.single.path != null) {
                  // 🌟 ఇక్కడ మార్పు: ఆడియో ట్రిమ్మర్ కి వెళ్లకుండా, డైరెక్ట్ గా పాత్ తీసుకుంటున్నాం
                  setState(() {
                    _isLocalAudio = true;
                    _localAudioPath = result.files.single.path!;
                    _audioName =
                        result.files.single.name; // ఫైల్ పేరు చూపిస్తుంది
                  });
                  _startMagicReel();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _startMagicReel() async {
    if (_selectedImages.isEmpty) return;
    _stopMagicReel();
    setState(() => _isPlaying = true);

    try {
      if (_isLocalAudio && _localAudioPath != null) {
        await _audioPlayer.play(DeviceFileSource(_localAudioPath!));
      } else {
        await _audioPlayer.play(UrlSource(trendingMusicUrl));
      }
    } catch (e) {
      debugPrint("Audio Error: $e");
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
        if (_elapsedSeconds % 2 == 0) {
          _currentIndex = (_currentIndex + 1) % _selectedImages.length;
        }
        if (_elapsedSeconds >= _maxSeconds) {
          _stopMagicReel();
        }
      });
    });
  }

  void _stopMagicReel() {
    _timer?.cancel();
    _audioPlayer.pause();
    if (mounted) setState(() => _isPlaying = false);
  }

  void _uploadAutoReel() {
    if (_selectedImages.isEmpty) return;
    _stopMagicReel();

    // 🌟 UploadManager ద్వారా అప్‌లోడ్ (ఇది `posts` కలెక్షన్ లో సేవ్ అవుతుంది మనం ముందు మార్చినట్లు)
    UploadManager().backgroundUploadAutoReel(
      images: _selectedImages,
      caption: "${_captionController.text.trim()}\n#AutoReel",
      isLocalAudio: _isLocalAudio,
      localAudioPath: _localAudioPath,
      trendingAudioUrl: trendingMusicUrl,
    );

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Auto Reel", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _uploadAutoReel,
            child: const Text(
              "Share",
              style: TextStyle(
                color: Colors.blueAccent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _selectedImages.isEmpty
          ? Center(
              child: ElevatedButton(
                onPressed: _pickImages,
                child: const Text("Select Photos"),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.file(
                        _selectedImages[_currentIndex],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                      GestureDetector(
                        onTap: _isPlaying ? _stopMagicReel : _startMagicReel,
                        child: CircleAvatar(
                          backgroundColor: Colors.black45,
                          radius: 30,
                          child: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  title: Text(
                    _audioName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.music_note,
                      color: Colors.blueAccent,
                    ),
                    onPressed: _showMusicPicker,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: TextField(
                    controller: _captionController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Write a caption...",
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                    ),
                    maxLines: 3,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }
}
