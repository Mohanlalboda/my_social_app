import 'dart:convert'; // 🌟 Base64 కోసం ఇది ముఖ్యం
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;

class StoryScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const StoryScreen({super.key, required this.user});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // 🌟 స్టోరీ వీడియో అయితే దాన్ని లోడ్ చేస్తున్నాం
    if (widget.user['type'] == 'video' && widget.user['storyUrl'] != null) {
      _videoController =
          VideoPlayerController.networkUrl(Uri.parse(widget.user['storyUrl']))
            ..initialize().then((_) {
              if (mounted) {
                setState(() => _isInitialized = true);
                _videoController!.play();
                _videoController!.setLooping(true);
              }
            });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String timeStr = widget.user['timestamp'] != null
        ? timeago.format((widget.user['timestamp'] as Timestamp).toDate())
        : "";

    // 🌟 ప్రొఫైల్ పిక్ బేస్64 డేటా అయితే దాన్ని డీకోడ్ చేయడం
    ImageProvider? profileImage;
    if (widget.user['profilePic'] != null &&
        widget.user['profilePic'].toString().isNotEmpty) {
      try {
        profileImage = MemoryImage(base64Decode(widget.user['profilePic']));
      } catch (e) {
        debugPrint("Profile Pic Error: $e");
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. మెయిన్ కంటెంట్ (Image or Video)
          Center(
            child: widget.user['type'] == 'video'
                ? (_isInitialized
                      ? AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        )
                      : const CircularProgressIndicator(color: Colors.white))
                : Image.network(
                    widget.user['storyUrl'] ?? "",
                    fit: BoxFit.contain,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 50,
                    ),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                  ),
          ),

          // 2. టాప్ బార్ (User Info & Close Button)
          Positioned(
            top: 50,
            left: 15,
            right: 15,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  backgroundImage: profileImage,
                  child: profileImage == null
                      ? Text(
                          widget.user['username'][0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user['username'] ?? "User",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
