// lib/screens/home/widgets/home_post_card.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:visibility_detector/visibility_detector.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 🌟 THE FIX
import '../hashtag_feed_screen.dart';

import '../../../services/firestore_methods.dart';
import '../../profile/profile_screen.dart';
import '../comments_screen.dart';
import '../../../widgets/universal_share_sheet.dart';

class HomePostCard extends StatefulWidget {
  final Map<String, dynamic> postData;
  final String postId;
  final bool isActive;

  const HomePostCard({
    super.key,
    required this.postData,
    required this.postId,
    this.isActive = false,
  });

  @override
  State<HomePostCard> createState() => _HomePostCardState();
}

class _HomePostCardState extends State<HomePostCard> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isAudio = false;
  bool _showHeartAnimation = false;
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  bool _isFollowing = false;
  int _commentCount = 0;
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isSaved = false;
  int _currentImageIndex = 0;
  bool _isCaptionExpanded = false;

  late final Key _visibilityKey;

  @override
  void initState() {
    super.initState();
    _visibilityKey = Key('post_${widget.postId}_$hashCode');
    String type = widget.postData['type'] ?? '';

    List<dynamic> mediaList =
        widget.postData['postUrls'] ?? widget.postData['postData'] ?? [];
    String postUrl = mediaList.isNotEmpty
        ? mediaList[0]
        : (widget.postData['postUrl'] ?? widget.postData['videoUrl'] ?? '');

    _isAudio =
        type == 'audio' ||
        postUrl.contains('.m4a') ||
        postUrl.contains('.mp3') ||
        postUrl.contains('.aac');
    _isLiked = (widget.postData['likes'] ?? []).contains(currentUid);
    _likeCount = (widget.postData['likes'] ?? []).length;
    _isSaved = (widget.postData['savedBy'] ?? widget.postData['saved'] ?? [])
        .contains(currentUid);

    _fetchCommentCount();
    _checkIfFollowing();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
  }

  void _fetchCommentCount() async {
    try {
      var snap = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .get();
      if (mounted) setState(() => _commentCount = snap.docs.length);
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _checkIfFollowing() async {
    String postUid = widget.postData['uid'] ?? widget.postData['ownerId'] ?? '';
    if (postUid.isNotEmpty && postUid != currentUid) {
      try {
        var snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .get();
        List following = snap.data()?['following'] ?? [];
        if (mounted) setState(() => _isFollowing = following.contains(postUid));
      } catch (e) {
        debugPrint("Error: $e");
      }
    }
  }

  void _toggleFollow() async {
    setState(() => _isFollowing = !_isFollowing);
    String targetUid =
        widget.postData['uid'] ?? widget.postData['ownerId'] ?? '';

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
    FirestoreMethods().likePost(
      widget.postId,
      currentUid,
      widget.postData['likes'] ?? [],
    );
  }

  void _toggleSave() {
    setState(() => _isSaved = !_isSaved);
    FirestoreMethods().savePost(
      widget.postId,
      currentUid,
      widget.postData['savedBy'] ?? widget.postData['saved'] ?? [],
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _openHashtagExplorer(String hashtag) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HashtagFeedScreen(hashtag: hashtag)),
    );
  }

  List<TextSpan> _buildCaptionSpans(String caption, Color defaultColor) {
    List<TextSpan> spans = [];
    List<String> words = caption.split(' ');
    for (var word in words) {
      if (word.startsWith('#')) {
        spans.add(
          TextSpan(
            text: '$word ',
            style: const TextStyle(
              color: Colors.blueAccent,
              fontWeight: FontWeight.bold,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _openHashtagExplorer(word),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: '$word ',
            style: TextStyle(color: defaultColor),
          ),
        );
      }
    }
    return spans;
  }

  void _showMoreOptions(bool isMine) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: isMine
            ? [
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Delete Post',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await FirestoreMethods().deletePost(widget.postId);
                  },
                ),
              ]
            : [
                ListTile(
                  leading: const Icon(Icons.flag, color: Colors.orange),
                  title: const Text(
                    'Report Post',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Post reported. 🛑")),
                    );
                  },
                ),
              ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    String postUid = widget.postData['ownerId'] ?? widget.postData['uid'] ?? '';
    String username = widget.postData['username'] ?? 'User';
    String profilePic = widget.postData['profilePic'] ?? '';
    String description =
        widget.postData['description'] ?? widget.postData['caption'] ?? '';

    List<dynamic> postUrls =
        widget.postData['postUrls'] ?? widget.postData['postData'] ?? [];
    String postUrl =
        widget.postData['postUrl'] ?? widget.postData['videoUrl'] ?? '';
    if (postUrls.isNotEmpty && postUrl.isEmpty) postUrl = postUrls[0];
    if (postUrls.isEmpty && postUrl.isNotEmpty) postUrls = [postUrl];

    bool isMine = currentUid == postUid;

    var timeData =
        widget.postData['datePublished'] ?? widget.postData['timestamp'];
    DateTime pubDate = DateTime.now();
    if (timeData is Timestamp)
      pubDate = timeData.toDate();
    else if (timeData is String)
      pubDate = DateTime.tryParse(timeData) ?? DateTime.now();

    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: (info) {
        try {
          if (info.visibleFraction < 0.2) {
            if (_isAudio && _isPlaying) {
              _audioPlayer.pause();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _isPlaying = false);
              });
            }
          }
        } catch (e) {debugPrint("Error: $e");}
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 50 : 15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (postUid.isNotEmpty)
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(userId: postUid),
                          ),
                        );
                    },
                    child: CircleAvatar(
                      radius: 20,
                      // 🌟 THE FIX: Cache Image
                      backgroundImage: CachedNetworkImageProvider(
                        profilePic.isNotEmpty
                            ? profilePic
                            : 'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: GestureDetector(
                                onTap: () {
                                  if (postUid.isNotEmpty)
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ProfileScreen(userId: postUid),
                                      ),
                                    );
                                },
                                child: Text(
                                  username,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (!isMine)
                              GestureDetector(
                                onTap: _toggleFollow,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isFollowing
                                        ? Colors.transparent
                                        : Colors.blueAccent.withAlpha(20),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _isFollowing ? "Following" : "Follow",
                                    style: TextStyle(
                                      color: _isFollowing
                                          ? Colors.grey
                                          : Colors.blueAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          timeago.format(pubDate),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showMoreOptions(isMine),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onDoubleTap: _toggleLike,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 480),
                color: isDark ? Colors.grey[950] : Colors.grey[50],
                child: _isAudio
                    ? Container(
                        height: 200,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF0F2027), Color(0xFF203A43)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white24,
                              child: CircleAvatar(
                                radius: 35,
                                // 🌟 THE FIX: Cache Image
                                backgroundImage: CachedNetworkImageProvider(
                                  profilePic.isNotEmpty
                                      ? profilePic
                                      : 'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            GestureDetector(
                              onTap: () async {
                                if (_isPlaying)
                                  await _audioPlayer.pause();
                                else
                                  await _audioPlayer.play(UrlSource(postUrl));
                                setState(() => _isPlaying = !_isPlaying);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(50),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      "Audio Post 🎙️",
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          PageView.builder(
                            itemCount: postUrls.length,
                            onPageChanged: (index) =>
                                setState(() => _currentImageIndex = index),
                            itemBuilder: (context, index) {
                              return InteractiveViewer(
                                child: postUrls[index].isNotEmpty
                                    // 🌟 THE FIX: Main Feed Post Image caching
                                    ? CachedNetworkImage(
                                        imageUrl: postUrls[index],
                                        fit: BoxFit.contain,
                                        placeholder: (context, url) =>
                                            const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                        errorWidget: (context, url, error) =>
                                            const Icon(
                                              Icons.broken_image,
                                              color: Colors.grey,
                                              size: 50,
                                            ),
                                      )
                                    : const Icon(
                                        Icons.image,
                                        color: Colors.grey,
                                        size: 50,
                                      ),
                              );
                            },
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
                          if (postUrls.length > 1)
                            Positioned(
                              bottom: 15,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  postUrls.length,
                                  (index) => Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    width: _currentImageIndex == index ? 8 : 6,
                                    height: _currentImageIndex == index ? 8 : 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _currentImageIndex == index
                                          ? Colors.blueAccent
                                          : Colors.white54,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 4.0,
                vertical: 4.0,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? Colors.redAccent : textColor,
                    ),
                    onPressed: _toggleLike,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.mode_comment_outlined,
                          color: textColor,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CommentsScreen(postId: widget.postId),
                          ),
                        ),
                      ),
                      Text(
                        '$_commentCount',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.near_me_outlined, color: textColor),
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      builder: (context) => UniversalShareSheet(
                        postId: widget.postId,
                        postType: _isAudio ? 'audio' : 'post',
                        mediaUrl: postUrl,
                        title: description,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _isSaved
                          ? Icons.bookmark
                          : Icons.bookmark_border_outlined,
                      color: textColor,
                    ),
                    onPressed: _toggleSave,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: 14.0,
                right: 14.0,
                bottom: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_likeCount > 0)
                    Text(
                      '$_likeCount likes',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
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
                            text: TextSpan(
                              style: TextStyle(color: textColor),
                              children: [
                                TextSpan(
                                  text: '$username ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                ..._buildCaptionSpans(description, textColor),
                              ],
                            ),
                          ),
                          if (!_isCaptionExpanded && description.length > 50)
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
                  if (_commentCount > 0) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CommentsScreen(postId: widget.postId),
                        ),
                      ),
                      child: const Text(
                        'View all comments',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
