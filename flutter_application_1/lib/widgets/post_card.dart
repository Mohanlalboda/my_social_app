// lib/widgets/post_card.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:share_plus/share_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/post_model.dart';
import '../services/firestore_methods.dart';
import '../screens/home/comments_screen.dart';
import '../screens/home/hashtag_feed_screen.dart';
import 'share_media_sheet.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  bool isFollowing = false;

  @override
  void initState() {
    super.initState();
    _checkIfFollowing();
  }

  void _checkIfFollowing() async {
    DocumentSnapshot snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .get();
    if (snap.exists && snap.data() != null) {
      List following = (snap.data() as Map<String, dynamic>)['following'] ?? [];
      if (mounted) {
        setState(() {
          isFollowing = following.contains(widget.post.uid);
        });
      }
    }
  }

  // 📝 Hashtags ని బ్లూ కలర్ లో మార్చే ఫంక్షన్
  List<TextSpan> _buildCaptionSpans(
    String description,
    BuildContext context,
    Color defaultTextColor,
  ) {
    List<TextSpan> spans = [];
    RegExp exp = RegExp(r"(\#\w+)|([^\#]+)");
    Iterable<RegExpMatch> matches = exp.allMatches(description);

    for (var match in matches) {
      String matchText = match.group(0)!;
      if (matchText.startsWith('#')) {
        spans.add(
          TextSpan(
            text: matchText,
            style: const TextStyle(
              color: Colors.blueAccent,
              fontWeight: FontWeight.bold,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HashtagFeedScreen(hashtag: matchText),
                  ),
                );
              },
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: matchText,
            style: TextStyle(color: defaultTextColor),
          ),
        );
      }
    }
    return spans;
  }

  // ⚙️ పైన ఉన్న 3 డాట్స్ నొక్కితే వచ్చే ఆప్షన్స్ (Delete, Share)
  void _showOptionsDialog(BuildContext context, String currentUid) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              if (widget.post.uid == currentUid)
                InkWell(
                  onTap: () async {
                    Navigator.pop(context);
                    String res = await FirestoreMethods().deletePost(
                      widget.post.postId,
                    );
                    if (!context.mounted) return;
                    if (res == "success") {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Post deleted successfully! 🗑️"),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.redAccent),
                        SizedBox(width: 12),
                        Text(
                          'Delete Post',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  SharePlus.instance.share(
                    ShareParams(
                      text:
                          "Check out this post by @${widget.post.username} on MyBanjara: \n${widget.post.postUrl}",
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined),
                      SizedBox(width: 12),
                      Text('Share Link', style: TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.close, color: Colors.grey),
                      SizedBox(width: 12),
                      Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    bool isMe = currentUid == widget.post.uid;
    bool isLiked = widget.post.likes.contains(currentUid);

    // ఆడియో ఫైల్ అవునో కాదో చెక్ చేస్తున్నాం
    final bool isAudio =
        widget.post.postUrl.contains('post_audios') ||
        widget.post.postUrl.contains('.m4a') ||
        widget.post.postUrl.contains('.mp3');

    // 🌟 NEW: చుట్టూ గ్యాప్ (margin) మరియు రౌండ్ కార్నర్స్
    return Container(
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
          // 👤 HEADER SECTION (Profile Pic, Name, Follow Button, 3 Dots)
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: CachedNetworkImageProvider(
                    widget.post.profilePic.isNotEmpty
                        ? widget.post.profilePic
                        : 'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
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
                            child: Text(
                              widget.post.username,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 🌟 NEW: Follow బటన్ పేరు పక్కన
                          if (!isMe)
                            GestureDetector(
                              onTap: () async {
                                await FirestoreMethods().followUser(
                                  currentUid,
                                  widget.post.uid,
                                );
                                setState(() => isFollowing = !isFollowing);
                              },
                              child: Text(
                                isFollowing ? "Following" : "• Follow",
                                style: TextStyle(
                                  color: isFollowing
                                      ? Colors.grey
                                      : Colors.blueAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        timeago.format(widget.post.datePublished),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // 🌟 3 Dots ఎప్పుడూ కుడి వైపు కార్నర్ లోనే ఉంటాయి
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showOptionsDialog(context, currentUid),
                ),
              ],
            ),
          ),

          // 📸 IMAGE / MEDIA SECTION
          GestureDetector(
            onDoubleTap: () => FirestoreMethods().likePost(
              widget.post.postId,
              currentUid,
              widget.post.likes,
            ),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 480),
              color: isDark ? Colors.grey[950] : Colors.grey[50],
              // ఆడియో అయితే ప్లేయర్, ఇమేజ్ అయితే ఫోటో
              child: isAudio
                  ? AudioFeedPlayer(audioUrl: widget.post.postUrl)
                  : (widget.post.postUrl.isNotEmpty
                        ? CachedNetworkImage(
                            // 🌟 THE FIX
                            imageUrl: widget.post.postUrl,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : const SizedBox.shrink()),
            ),
          ),

          // ❤️ LIKES, COMMENTS, SHARE, SAVE SECTION
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.redAccent : textColor,
                  ),
                  onPressed: () => FirestoreMethods().likePost(
                    widget.post.postId,
                    currentUid,
                    widget.post.likes,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.mode_comment_outlined, color: textColor),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CommentsScreen(postId: widget.post.postId),
                        ),
                      ),
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('posts')
                          .doc(widget.post.postId)
                          .collection('comments')
                          .snapshots(),
                      builder: (context, commentSnap) {
                        int count = commentSnap.hasData
                            ? commentSnap.data!.docs.length
                            : 0;
                        return Text(
                          '$count',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: textColor,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.near_me_outlined, color: textColor),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      builder: (context) => ShareMediaSheet(
                        mediaId: widget.post.postId,
                        mediaUrl: widget.post.postUrl,
                        isReel: false,
                      ),
                    );
                  },
                ),
                const Spacer(),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .doc(widget.post.postId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    List savedBy = [];
                    if (snapshot.hasData && snapshot.data!.exists) {
                      Map<String, dynamic>? postData =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      if (postData != null && postData['savedBy'] != null) {
                        savedBy = postData['savedBy'];
                      }
                    }
                    bool isSaved = savedBy.contains(currentUid);

                    return IconButton(
                      icon: Icon(
                        isSaved
                            ? Icons.bookmark
                            : Icons.bookmark_border_outlined,
                        color: textColor,
                      ),
                      onPressed: () => FirestoreMethods().savePost(
                        widget.post.postId,
                        currentUid,
                        savedBy,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // 📝 DESCRIPTION & LIKES COUNT
          Padding(
            padding: const EdgeInsets.only(
              left: 14.0,
              right: 14.0,
              bottom: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.post.likes.isNotEmpty)
                  Text(
                    '${widget.post.likes.length} likes',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                if (widget.post.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(color: textColor),
                      children: [
                        TextSpan(
                          text: '${widget.post.username} ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ..._buildCaptionSpans(
                          widget.post.description,
                          context,
                          textColor,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CommentsScreen(postId: widget.post.postId),
                    ),
                  ),
                  child: const Text(
                    'View all comments',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 🎙️ ఫీడ్ లో ఆడియో ప్లే అవ్వడానికి మన సొంత ఆడియో ప్లేయర్ విడ్జెట్
class AudioFeedPlayer extends StatefulWidget {
  final String audioUrl;
  const AudioFeedPlayer({super.key, required this.audioUrl});

  @override
  State<AudioFeedPlayer> createState() => _AudioFeedPlayerState();
}

class _AudioFeedPlayerState extends State<AudioFeedPlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.deepPurpleAccent, Colors.blueAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.deepPurpleAccent,
                    size: 30,
                  ),
                  onPressed: () {
                    if (_isPlaying) {
                      _audioPlayer.pause();
                    } else {
                      _audioPlayer.play(UrlSource(widget.audioUrl));
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Voice Note 🎙️",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        min: 0,
                        max: _duration.inSeconds.toDouble() > 0
                            ? _duration.inSeconds.toDouble()
                            : 1,
                        value: _position.inSeconds.toDouble().clamp(
                          0,
                          _duration.inSeconds.toDouble() > 0
                              ? _duration.inSeconds.toDouble()
                              : 1,
                        ),
                        activeColor: Colors.white,
                        inactiveColor: Colors.white38,
                        onChanged: (val) {
                          _audioPlayer.seek(Duration(seconds: val.toInt()));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _formatDuration(_duration),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
