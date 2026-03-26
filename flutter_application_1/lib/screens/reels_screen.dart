// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🌟 ఇప్పుడు వాడుతున్నాం
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../widgets/safe_elements.dart';
import 'other_user_profile_screen.dart'; // 🌟 ఇప్పుడు వాడుతున్నాం
import 'comments_screen.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('type', isEqualTo: 'video')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.white),
              ),
            );
          if (!snapshot.hasData)
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );

          var reels = snapshot.data!.docs;
          if (reels.isEmpty)
            return const Center(
              child: Text(
                "No Reels Found. 🎬",
                style: TextStyle(color: Colors.white70),
              ),
            );

          return PageView.builder(
            scrollDirection: Axis.vertical,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: reels.length,
            itemBuilder: (context, index) {
              var data = reels[index].data() as Map<String, dynamic>;
              data['postId'] = reels[index].id;
              return ReelItem(
                key: ValueKey(data['postId']),
                reel: data,
                index: index,
                currentPage: _currentPage,
              );
            },
          );
        },
      ),
    );
  }
}

class ReelItem extends StatefulWidget {
  final Map<String, dynamic> reel;
  final int index;
  final int currentPage;
  const ReelItem({
    super.key,
    required this.reel,
    required this.index,
    required this.currentPage,
  });

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool isLiked = false;
  // 🌟 FirebaseAuth ఇక్కడ వాడుతున్నాం
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _initLikeStatus();
    _checkAndInit();
  }

  void _initLikeStatus() {
    List likes = widget.reel['likes'] ?? [];
    isLiked = likes.contains(currentUid);
  }

  void _checkAndInit() {
    bool shouldBeLoaded =
        (widget.index >= widget.currentPage - 1 &&
        widget.index <= widget.currentPage + 1);
    if (shouldBeLoaded && _controller == null) {
      String url =
          (widget.reel['postData'] is List &&
              widget.reel['postData'].isNotEmpty)
          ? widget.reel['postData'][0]
          : (widget.reel['storyUrl'] ?? "");

      if (url.isNotEmpty) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(url))
          ..initialize().then((_) {
            if (mounted) {
              setState(() {
                _isInitialized = true;
                _controller!.setLooping(true);
                if (widget.index == widget.currentPage) _controller!.play();
              });
            }
          });
      }
    }
  }

  @override
  void didUpdateWidget(ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkAndInit();
    if (_isInitialized && _controller != null) {
      (widget.index == widget.currentPage)
          ? _controller!.play()
          : _controller!.pause();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // 🌟 లైక్ కొట్టే ఫంక్షన్
  void _handleLike() async {
    setState(() => isLiked = !isLiked);
    var ref = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.reel['postId']);
    isLiked
        ? await ref.update({
            'likes': FieldValue.arrayUnion([currentUid]),
          })
        : await ref.update({
            'likes': FieldValue.arrayRemove([currentUid]),
          });
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.reel['postId']),
      onVisibilityChanged: (info) {
        // 🌟 ముందుగా వీడియో కంట్రోలర్ ఉందో లేదో చెక్ చేయాలి
        if (!mounted || _controller == null || !_isInitialized) return;

        // వీడియో ప్లే/పాజ్ లాజిక్
        if (info.visibleFraction > 0.8) {
          _controller!.play();
        } else {
          // 🌟 కంట్రోలర్ ఇంకా యాక్టివ్ గా ఉంటేనే పాజ్ చేయాలి
          if (_controller!.value.isPlaying) {
            _controller!.pause();
          }
        }
      },
      child: GestureDetector(
        onTap: () {
          if (_isInitialized && _controller != null) {
            _controller!.value.isPlaying
                ? _controller!.pause()
                : _controller!.play();
            setState(() {});
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            _isInitialized && _controller != null
                ? Center(
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white24),
                  ),

            if (_isInitialized &&
                _controller != null &&
                !_controller!.value.isPlaying)
              const Center(
                child: Icon(Icons.play_arrow, color: Colors.white54, size: 80),
              ),

            // యూజర్ ఇన్ఫో & నేవిగేషన్
            Positioned(
              bottom: 25,
              left: 15,
              right: 70,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    // 🌟 OtherUserProfileScreen ఇక్కడ వాడుతున్నాం
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            OtherUserProfileScreen(uid: widget.reel['ownerId']),
                      ),
                    ),
                    child: Row(
                      children: [
                        SafeProfilePic(
                          base64String: widget.reel['profilePic'],
                          radius: 18,
                          fallbackText: "U",
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.reel['username'] ?? "User",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.reel['caption'] ?? "",
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            // రైట్ సైడ్ బటన్స్
            Positioned(
              right: 15,
              bottom: 100,
              child: Column(
                children: [
                  IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : Colors.white,
                      size: 32,
                    ),
                    onPressed: _handleLike,
                  ),
                  const Text(
                    "Like",
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  IconButton(
                    icon: const Icon(
                      Icons.comment_outlined,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommentsScreen(
                          postId: widget.reel['postId'],
                          postOwnerId: widget.reel['ownerId'],
                          isReel: true,
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    "Comment",
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  const Icon(
                    Icons.bookmark_border,
                    color: Colors.white,
                    size: 32,
                  ),
                  const Text(
                    "Save",
                    style: TextStyle(color: Colors.white, fontSize: 12),
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
