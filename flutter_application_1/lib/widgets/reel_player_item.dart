import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import '../models/reel_model.dart';
import '../services/firestore_methods.dart';
import '../screens/home/reel_comments_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ReelPlayerItem extends StatefulWidget {
  final ReelModel reel;
  const ReelPlayerItem({super.key, required this.reel});

  @override
  State<ReelPlayerItem> createState() => _ReelPlayerItemState();
}

class _ReelPlayerItemState extends State<ReelPlayerItem> {
  late CachedVideoPlayerPlus _videoPlayer;
  bool _isPlaying = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() {
    // 🌟 THE FIX: ఎర్రర్ వస్తే యాప్ క్రాష్ కాకుండా ఇక్కడ ఆపుతున్నాం (catchError) బాస్!
    _videoPlayer =
        CachedVideoPlayerPlus.networkUrl(Uri.parse(widget.reel.videoUrl))
          ..initialize()
              .then((_) {
                if (mounted) {
                  setState(() {
                    _isInitialized = true;
                  });
                  _videoPlayer.controller.play();
                  _videoPlayer.controller.setLooping(true);
                }
              })
              .catchError((error) {
                debugPrint(
                  "🚨 Video Format Unsupported/Error in ReelPlayer: $error",
                );
                // క్రాష్ అవ్వదు, జస్ట్ లాగ్ లో ఎర్రర్ చూపిస్తుంది!
              });
  }

  @override
  void dispose() {
    _videoPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final String currentUid = FirebaseAuth.instance.currentUser!.uid;
    final bool isLiked = widget.reel.likes.contains(currentUid);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          if (_videoPlayer.controller.value.isPlaying) {
            _videoPlayer.controller.pause();
            setState(() => _isPlaying = false);
          } else {
            _videoPlayer.controller.play();
            setState(() => _isPlaying = true);
          }
        },
        onDoubleTap: () => FirestoreMethods().likeReel(
          widget.reel.reelId,
          currentUid,
          widget.reel.likes,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 🌟 వీడియో ఇనిషియలైజ్ అయితేనే ప్లేయర్ చూపిస్తాం, లేదంటే లోడింగ్ చూపిస్తాం
            _isInitialized
                ? SizedBox(
                    width: size.width,
                    height: size.height,
                    child: VideoPlayer(_videoPlayer.controller),
                  )
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),

            if (!_isPlaying && _isInitialized)
              const CircleAvatar(
                radius: 30,
                backgroundColor: Colors.black45,
                child: Icon(Icons.play_arrow, size: 40, color: Colors.white),
              ),

            // 👉 రైట్ సైడ్ యాక్షన్ బటన్స్ (Likes & Comments)
            Positioned(
              bottom: 100,
              right: 15,
              child: Column(
                children: [
                  IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 35,
                      color: isLiked ? Colors.red : Colors.white,
                    ),
                    onPressed: () => FirestoreMethods().likeReel(
                      widget.reel.reelId,
                      currentUid,
                      widget.reel.likes,
                    ),
                  ),
                  Text(
                    '${widget.reel.likes.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // 💬 కామెంట్ బటన్ లింక్
                  IconButton(
                    icon: const Icon(
                      Icons.comment_outlined,
                      size: 35,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ReelCommentsScreen(reelId: widget.reel.reelId),
                      ),
                    ),
                  ),
                  const Text(
                    'Comments',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ],
              ),
            ),

            // 👉 బాటమ్ యూజర్ డీటెయిల్స్ & క్యాప్షన్
            Positioned(
              bottom: 40,
              left: 15,
              right: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 16,
                        backgroundImage: CachedNetworkImageProvider(
                          'https://cdn.pixabay.com/photo/...',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.reel.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.reel.caption,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
