// lib/screens/home/widgets/home_reel_card.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 🌟 THE FIX

import '../../../services/firestore_methods.dart';
import '../comments_screen.dart';
import '../../../widgets/universal_share_sheet.dart';
import '../hashtag_feed_screen.dart';

class HomeReelCard extends StatefulWidget {
  final Map<String, dynamic> reelData;
  final String reelId;
  final bool isActive;
  const HomeReelCard({
    super.key,
    required this.reelData,
    required this.reelId,
    this.isActive = false,
  });
  @override
  State<HomeReelCard> createState() => _HomeReelCardState();
}

class _HomeReelCardState extends State<HomeReelCard>
    with WidgetsBindingObserver {
  CachedVideoPlayerPlus? _videoPlayer;
  bool _isInitialized = false;
  bool _wasPlayingBeforePause = false;
  static final ValueNotifier<bool> _globalMuteNotifier = ValueNotifier<bool>(
    true,
  );

  bool _showHeartAnimation = false;
  bool _isCaptionExpanded = false;

  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isSaved = false;
  bool _isFollowing = false;
  int _commentCount = 0;

  late final Key _visibilityKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _visibilityKey = Key('reel_${widget.reelId}_$hashCode');

    _isLiked = (widget.reelData['likes'] ?? []).contains(currentUid);
    _likeCount = (widget.reelData['likes'] ?? []).length;
    _isSaved = (widget.reelData['savedBy'] ?? widget.reelData['saved'] ?? [])
        .contains(currentUid);

    _fetchCommentCount();
    _checkIfFollowing();
    _initializeVideo();

    _globalMuteNotifier.addListener(_onMuteChanged);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_isInitialized &&
          _videoPlayer != null &&
          _videoPlayer!.controller.value.isPlaying) {
        _wasPlayingBeforePause = true;
        _videoPlayer!.controller.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_wasPlayingBeforePause && _isInitialized && _videoPlayer != null) {
        _videoPlayer!.controller.play();
        _wasPlayingBeforePause = false;
      }
    }
  }

  void _onMuteChanged() {
    if (_isInitialized && _videoPlayer != null) {
      _videoPlayer!.controller.setVolume(_globalMuteNotifier.value ? 0.0 : 1.0);
    }
  }

  void _fetchCommentCount() async {
    try {
      var snap = await FirebaseFirestore.instance
          .collection('reels')
          .doc(widget.reelId)
          .collection('comments')
          .get();
      if (mounted) setState(() => _commentCount = snap.docs.length);
    } catch (e) {debugPrint("Error: $e");}
  }

  void _checkIfFollowing() async {
    String postUid = widget.reelData['uid'] ?? widget.reelData['ownerId'] ?? '';
    if (postUid.isNotEmpty && postUid != currentUid) {
      try {
        var snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .get();
        List following = snap.data()?['following'] ?? [];
        if (mounted) setState(() => _isFollowing = following.contains(postUid));
      } catch (e) {debugPrint("Error: $e");}
    }
  }

  void _toggleFollow() async {
    setState(() => _isFollowing = !_isFollowing);
    String targetUid =
        widget.reelData['uid'] ?? widget.reelData['ownerId'] ?? '';
    if (targetUid.isEmpty) return;

    try {
      if (_isFollowing) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .update({
              'following': FieldValue.arrayUnion([targetUid]),
            });
        await FirebaseFirestore.instance
            .collection('users')
            .doc(targetUid)
            .update({
              'followers': FieldValue.arrayUnion([currentUid]),
            });
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .update({
              'following': FieldValue.arrayRemove([targetUid]),
            });
        await FirebaseFirestore.instance
            .collection('users')
            .doc(targetUid)
            .update({
              'followers': FieldValue.arrayRemove([currentUid]),
            });
      }
    } catch (e) {
      if (mounted) setState(() => _isFollowing = !_isFollowing);
    }
  }

  void _toggleLike() {
    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likeCount = (_likeCount > 0) ? _likeCount - 1 : 0;
      } else {
        _isLiked = true;
        _likeCount += 1;
        _showHeartAnimation = true;
        Timer(const Duration(milliseconds: 700), () {
          if (mounted) setState(() => _showHeartAnimation = false);
        });
      }
    });
    FirestoreMethods().likeReel(
      widget.reelId,
      currentUid,
      widget.reelData['likes'] ?? [],
    );
  }

  void _toggleSave() {
    setState(() => _isSaved = !_isSaved);
    FirestoreMethods().saveReel(
      widget.reelId,
      currentUid,
      widget.reelData['savedBy'] ?? widget.reelData['saved'] ?? [],
    );
  }

  void _initializeVideo() {
    List mediaList = widget.reelData['postData'] ?? [];
    String videoUrl = mediaList.isNotEmpty
        ? mediaList[0]
        : (widget.reelData['videoUrl'] ?? '');

    if (videoUrl.isNotEmpty) {
      _videoPlayer = CachedVideoPlayerPlus.networkUrl(Uri.parse(videoUrl))
        ..initialize().then((_) {
          if (mounted) {
            setState(() => _isInitialized = true);
            _videoPlayer?.controller.setLooping(true);
            _videoPlayer?.controller.setVolume(
              _globalMuteNotifier.value ? 0.0 : 1.0,
            );
            if (widget.isActive) _videoPlayer?.controller.play();
          }
        });
    }
  }

  void _openHashtagExplorer(String hashtag) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HashtagFeedScreen(hashtag: hashtag)),
    );
  }

  List<TextSpan> _buildCaptionSpans(String caption) {
    List<TextSpan> spans = [];
    List<String> words = caption.split(' ');
    for (var word in words) {
      if (word.startsWith('#'))
        spans.add(
          TextSpan(
            text: '$word ',
            style: const TextStyle(
              color: Colors.blueAccent,
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _openHashtagExplorer(word),
          ),
        );
      else
        spans.add(
          TextSpan(
            text: '$word ',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        );
    }
    return spans;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _globalMuteNotifier.removeListener(_onMuteChanged);
    _videoPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String reelUid = widget.reelData['ownerId'] ?? widget.reelData['uid'] ?? '';
    String username = widget.reelData['username'] ?? 'User';
    String caption =
        widget.reelData['caption'] ?? widget.reelData['description'] ?? '';
    String rProfilePic = widget.reelData['profilePic'] ?? '';
    bool isMine = currentUid == reelUid;

    List mediaListBuild = widget.reelData['postData'] ?? [];
    String shareVideoUrl = mediaListBuild.isNotEmpty
        ? mediaListBuild[0]
        : (widget.reelData['videoUrl'] ?? '');

    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: (info) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          try {
            if (_isInitialized && _videoPlayer != null) {
              if (info.visibleFraction > 0.6) {
                if (!_videoPlayer!.controller.value.isPlaying)
                  _videoPlayer!.controller.play();
              } else {
                if (_videoPlayer!.controller.value.isPlaying)
                  _videoPlayer!.controller.pause();
              }
            }
          } catch (e) {debugPrint("Error: $e");}
        });
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(color: Colors.black),
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () {
                if (_isInitialized && _videoPlayer != null) {
                  setState(() {
                    _videoPlayer!.controller.value.isPlaying
                        ? _videoPlayer!.controller.pause()
                        : _videoPlayer!.controller.play();
                  });
                }
              },
              onDoubleTap: _toggleLike,
              child: SizedBox.expand(
                child: _isInitialized && _videoPlayer != null
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _videoPlayer!.controller.value.size.width,
                          height: _videoPlayer!.controller.value.size.height,
                          child: VideoPlayer(_videoPlayer!.controller),
                        ),
                      )
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
              ),
            ),
            if (_showHeartAnimation)
              AnimatedScale(
                duration: const Duration(milliseconds: 250),
                scale: _showHeartAnimation ? 1.2 : 0.0,
                child: const Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 85,
                ),
              ),

            Positioned(
              top: 20,
              left: 15,
              child: ValueListenableBuilder<bool>(
                valueListenable: _globalMuteNotifier,
                builder: (context, isMuted, child) {
                  return CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        isMuted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: () => _globalMuteNotifier.value = !isMuted,
                    ),
                  );
                },
              ),
            ),
            Positioned(
              right: 15,
              bottom: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? Colors.red : Colors.white,
                      size: 30,
                    ),
                    onPressed: _toggleLike,
                  ),
                  Text(
                    '$_likeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  IconButton(
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommentsScreen(postId: widget.reelId),
                      ),
                    ),
                  ),
                  Text(
                    '$_commentCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  IconButton(
                    icon: const Icon(
                      Icons.near_me_outlined,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => UniversalShareSheet(
                          postId: widget.reelId,
                          postType: 'reel',
                          mediaUrl: shareVideoUrl,
                          title: caption,
                        ),
                      );
                    },
                  ),
                  const Text(
                    'Share',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  IconButton(
                    icon: Icon(
                      _isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: _isSaved ? Colors.amber[400] : Colors.white,
                      size: 30,
                    ),
                    onPressed: _toggleSave,
                  ),
                  const Text(
                    'Save',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 15,
              bottom: 20,
              right: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        // 🌟 THE FIX: Reel Profile Cache
                        backgroundImage: CachedNetworkImageProvider(
                          rProfilePic.isNotEmpty
                              ? rProfilePic
                              : 'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          shadows: [
                            Shadow(blurRadius: 4, color: Colors.black45),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Reel 🎬',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setState(
                      () => _isCaptionExpanded = !_isCaptionExpanded,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          maxLines: _isCaptionExpanded ? null : 2,
                          overflow: _isCaptionExpanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                          text: TextSpan(children: _buildCaptionSpans(caption)),
                        ),
                        if (!_isCaptionExpanded && caption.length > 50)
                          const Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            child: Text(
                              "...Read more",
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 20,
              right: 15,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMine)
                    GestureDetector(
                      onTap: _toggleFollow,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white),
                          borderRadius: BorderRadius.circular(20),
                          color: _isFollowing
                              ? Colors.white24
                              : Colors.transparent,
                        ),
                        child: Text(
                          _isFollowing ? 'Following' : 'Follow',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
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
