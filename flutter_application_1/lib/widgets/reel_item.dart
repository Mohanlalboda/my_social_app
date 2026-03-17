import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../screens/comments_screen.dart';

class ReelItem extends StatefulWidget {
  final Map<String, dynamic> reel;
  final String reelId;

  const ReelItem({super.key, required this.reel, required this.reelId});

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  Map<String, dynamic> get reelData => widget.reel;

  late VideoPlayerController _controller;
  bool _isInitialized = false;

  bool _isLiked = false;
  int _likeCount = 0;

  bool _isSaved = false;

  late String currentUid;
  late String reelOwnerId;

  @override
  void initState() {
    super.initState();
    currentUid = FirebaseAuth.instance.currentUser!.uid;
    reelOwnerId = reelData['uid'] ?? reelData['ownerId'] ?? '';

    _syncData();

    _controller =
        VideoPlayerController.networkUrl(Uri.parse(reelData['videoUrl']))
          ..initialize().then((_) {
            if (mounted) {
              setState(() {
                _isInitialized = true;
              });
              _controller.setLooping(true);
              _controller.play();
            }
          });
  }

  @override
  void didUpdateWidget(ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncData();
  }

  void _syncData() {
    List likes = reelData['likes'] ?? [];
    _isLiked = likes.contains(currentUid);
    _likeCount = likes.length;

    List savedBy = reelData['savedBy'] ?? [];
    _isSaved = savedBy.contains(currentUid);
  }

  void _toggleSave() async {
    setState(() {
      _isSaved = !_isSaved;
    });

    try {
      if (_isSaved) {
        await FirebaseFirestore.instance
            .collection('reels')
            .doc(widget.reelId)
            .update({
              'savedBy': FieldValue.arrayUnion([currentUid]),
            });
      } else {
        await FirebaseFirestore.instance
            .collection('reels')
            .doc(widget.reelId)
            .update({
              'savedBy': FieldValue.arrayRemove([currentUid]),
            });
      }
    } catch (e) {
      debugPrint("Error toggling save: $e");
    }
  }

  void _toggleLike() async {
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        _likeCount++;
      } else {
        _likeCount--;
      }
    });

    try {
      if (_isLiked) {
        await FirebaseFirestore.instance
            .collection('reels')
            .doc(widget.reelId)
            .update({
              'likes': FieldValue.arrayUnion([currentUid]),
            });
      } else {
        await FirebaseFirestore.instance
            .collection('reels')
            .doc(widget.reelId)
            .update({
              'likes': FieldValue.arrayRemove([currentUid]),
            });
      }
    } catch (e) {
      debugPrint("🚨 Like Error: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildActionIcon({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isPlaying = _isInitialized ? _controller.value.isPlaying : false;

    return Stack(
      fit: StackFit.expand,
      children: [
        _isInitialized
            ? GestureDetector(
                onTap: () {
                  setState(() {
                    isPlaying ? _controller.pause() : _controller.play();
                  });
                },
                onDoubleTap: _toggleLike,
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                ),
              )
            : const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

        Positioned(
          bottom: 20,
          right: 15,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildActionIcon(
                icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                color: _isLiked ? Colors.red : Colors.white,
                label: _likeCount.toString(),
                onTap: _toggleLike,
              ),
              const SizedBox(height: 20),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('reels')
                    .doc(widget.reelId)
                    .collection('comments')
                    .snapshots(),
                builder: (context, snapshot) {
                  int commentCount = snapshot.hasData
                      ? snapshot.data!.docs.length
                      : 0;
                  return _buildActionIcon(
                    icon: Icons.chat_bubble_outline,
                    color: Colors.white,
                    label: commentCount.toString(),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CommentsScreen(
                            postId: widget.reelId,
                            isReel: true,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),

              _buildActionIcon(
                icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: _isSaved ? Colors.amber[400]! : Colors.white,
                label: "Save",
                onTap: _toggleSave,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
