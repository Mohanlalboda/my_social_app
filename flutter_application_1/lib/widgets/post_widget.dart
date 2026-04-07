// ignore_for_file: curly_braces_in_flow_control_structures, empty_catches

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/social_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'safe_elements.dart';
import 'cached_media_widget.dart';
import '../screens/posts/comments_screen.dart';
import '../screens/profile/other_user_profile_screen.dart';
import '../screens/profile/user_list_screen.dart';

class PostWidget extends StatefulWidget {
  final Map<String, dynamic> post;
  const PostWidget({super.key, required this.post});

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  bool isLiked = false;
  bool isSaved = false;
  int likeCount = 0;
  int _currentImageIndex = 0;
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  bool _showBigHeart = false;

  @override
  void initState() {
    super.initState();
    _syncData();
    _markPostAsSeen();
  }

  void _syncData() {
    List likes = widget.post['likes'] is List ? widget.post['likes'] : [];
    isLiked = likes.contains(currentUid);
    likeCount = likes.length;

    List savedBy = widget.post['savedBy'] is List ? widget.post['savedBy'] : [];
    isSaved = savedBy.contains(currentUid);
  }

  void _markPostAsSeen() async {
    List viewedBy = widget.post['viewedBy'] ?? [];
    if (!viewedBy.contains(currentUid)) {
      try {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.post['postId'])
            .set({
              'viewedBy': FieldValue.arrayUnion([currentUid]),
            }, SetOptions(merge: true));
      } catch (e) {}
    }
  }

  void _handleLike() async {
    setState(() {
      isLiked = !isLiked;
      isLiked ? likeCount++ : likeCount--;
    });

    SocialService.toggleLike(
      postId: widget.post['postId'],
      likesArray: widget.post['likes'] ?? [],
      isReel: false,
    );

    if (isLiked) {
      String postOwnerId = widget.post['ownerId'];
      if (currentUid != postOwnerId) {
        var myDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .get();
        String myName = myDoc.data()?['username'] ?? 'User';
        String myPic = myDoc.data()?['profilePic'] ?? '';
        String mediaUrl =
            (widget.post['postData'] is List &&
                widget.post['postData'].isNotEmpty)
            ? widget.post['postData'][0]
            : (widget.post['storyUrl'] ?? "");

        await FirebaseFirestore.instance
            .collection('users')
            .doc(postOwnerId)
            .collection('notifications')
            .add({
              'senderId': currentUid,
              'senderName': myName,
              'senderPic': myPic,
              'type': 'like',
              'postId': widget.post['postId'],
              'mediaUrl': mediaUrl,
              'isRead': false,
              'timestamp': FieldValue.serverTimestamp(),
            });
      }
    }
  }

  void _handleDoubleTap() {
    if (!isLiked) _handleLike();
    setState(() => _showBigHeart = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showBigHeart = false);
    });
  }

  void _handleSave() {
    setState(() => isSaved = !isSaved);
    SocialService.toggleSave(
      postId: widget.post['postId'],
      savedArray: widget.post['savedBy'] ?? [],
      isReel: false,
    );
  }

  void _shareExternally() async {
    try {
      String imageData = "";
      if (widget.post['postData'] is List &&
          (widget.post['postData'] as List).isNotEmpty) {
        imageData = widget.post['postData'][0].toString();
      } else {
        imageData = widget.post['postData']?.toString() ?? "";
      }
      if (imageData.isEmpty) return;

      if (imageData.startsWith('http')) {
        await SharePlus.instance.share(
          ShareParams(
            text:
                "${widget.post['caption'] ?? 'Check out this post!'}\n\n$imageData",
          ),
        );
      } else {
        if (imageData.contains(',')) imageData = imageData.split(',').last;
        final bytes = base64Decode(imageData.trim());
        final tempDir = await getTemporaryDirectory();
        final file = File(
          '${tempDir.path}/post_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await file.writeAsBytes(bytes);
        if (await file.exists()) {
          final xFile = XFile(file.path, mimeType: 'image/png');
          await SharePlus.instance.share(
            ShareParams(
              text: widget.post['caption'] ?? "Check out this post!",
              files: [xFile],
            ),
          );
        }
      }
    } catch (e) {}
  }

  void _sendPostInternally(
    BuildContext sheetContext,
    String receiverId,
    String receiverName,
  ) async {
    String url =
        (widget.post['postData'] is List && widget.post['postData'].isNotEmpty)
        ? widget.post['postData'][0]
        : "";
    String roomId = currentUid.hashCode <= receiverId.hashCode
        ? "${currentUid}_$receiverId"
        : "${receiverId}_$currentUid";
    var timestamp = FieldValue.serverTimestamp();

    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .add({
          'senderId': currentUid,
          'receiverId': receiverId,
          'text': "Sent a Post",
          'type': 'shared_post',
          'mediaUrl': url,
          'sharedPostId': widget.post['postId'],
          'ownerName': widget.post['username'] ?? 'User',
          'isRead': false,
          'timestamp': timestamp,
          'isEdited': false,
          'isDeleted': false,
          'deletedBy': [],
        });

    await FirebaseFirestore.instance.collection('chatRooms').doc(roomId).set({
      'users': [currentUid, receiverId],
      'lastMessage': "📷 Sent a Post",
      'timestamp': timestamp,
      'unread_$receiverId': FieldValue.increment(1),
    }, SetOptions(merge: true));

    if (!sheetContext.mounted) return;
    Navigator.pop(sheetContext);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Sent to $receiverName ✅"),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showShareMenu() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(15),
              child: Text(
                "Share Post",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUid)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  List following =
                      (snapshot.data!.data()
                          as Map<String, dynamic>)['following'] ??
                      [];
                  if (following.isEmpty)
                    return const Center(
                      child: Text(
                        "Follow someone to share with them!",
                        style: TextStyle(color: Colors.grey),
                      ),
                    );

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: following.length,
                    itemBuilder: (context, index) {
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(following[index])
                            .get(),
                        builder: (context, userSnap) {
                          if (!userSnap.hasData || !userSnap.data!.exists)
                            return const SizedBox();
                          var userData =
                              userSnap.data!.data() as Map<String, dynamic>;
                          return ListTile(
                            leading: SafeProfilePic(
                              base64String: userData['profilePic'],
                              radius: 20,
                              fallbackText: userData['username'][0],
                            ),
                            title: Text(
                              userData['username'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF007AFF),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              onPressed: () => _sendPostInternally(
                                ctx,
                                following[index],
                                userData['username'],
                              ),
                              child: const Text(
                                "Send",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.share, color: Colors.white),
              ),
              title: const Text(
                "Share to External Apps",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _shareExternally();
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _deletePost() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Post?"),
        content: const Text("Are you sure? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post['postId'])
          .delete();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Post Deleted!")));
    }
  }

  void _editPost() {
    TextEditingController editController = TextEditingController(
      text: widget.post['caption']?.toString() ?? "",
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Caption"),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
            hintText: "Enter new caption",
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.post['postId'])
                  .update({'caption': editController.text.trim()});
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Caption Updated!")),
                );
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    String username = widget.post['username'] ?? "User";
    String timeStr = widget.post['timestamp'] != null
        ? timeago.format((widget.post['timestamp'] as Timestamp).toDate())
        : "Just now";
    String postType = widget.post['type'] ?? 'image';

    List<String> images = [];
    if (widget.post['postData'] is List) {
      images = List<String>.from(widget.post['postData']);
    } else if (widget.post['postData'] is String &&
        widget.post['postData'].toString().isNotEmpty) {
      images = [widget.post['postData']];
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 0,
      color: isDark ? Colors.black : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    OtherUserProfileScreen(userId: widget.post['ownerId']),
              ),
            ),
            leading: SafeProfilePic(
              base64String: widget.post['profilePic'],
              radius: 20,
              fallbackText: username.isNotEmpty ? username[0] : "U",
            ),
            title: Text(
              username,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(timeStr, style: const TextStyle(fontSize: 12)),
            trailing: widget.post['ownerId'] == currentUid
                ? PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'edit') _editPost();
                      if (val == 'delete') _deletePost();
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'edit', child: Text("Edit")),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          "Delete",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  )
                : null,
          ),

          if (postType == 'auto_reel' && images.isNotEmpty)
            Stack(
              alignment: Alignment.center,
              children: [
                AutoReelPlayerForFeed(
                  imageUrls: images,
                  audioUrl: widget.post['audioUrl'] ?? '',
                  onDoubleTap: _handleDoubleTap,
                ),
                if (_showBigHeart)
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.5, end: 1.2),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) => Transform.scale(
                      scale: scale,
                      child: Icon(
                        Icons.favorite,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 100,
                      ),
                    ),
                  ),
              ],
            )
          else if (images.isNotEmpty)
            Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.width * 1.3,
                  ),
                  width: double.infinity,
                  color: isDark ? Colors.black : Colors.grey[100],
                  child: PageView.builder(
                    onPageChanged: (index) =>
                        setState(() => _currentImageIndex = index),
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      String imgData = images[index];
                      return GestureDetector(
                        onDoubleTap: _handleDoubleTap,
                        child: imgData.startsWith('http')
                            ? CachedMediaWidget(
                                mediaUrl: imgData,
                                type: postType,
                                isGrid: false,
                              )
                            : SafeImage(
                                base64String: imgData,
                                fit: BoxFit.contain,
                              ),
                      );
                    },
                  ),
                ),
                if (images.length > 1)
                  Positioned(
                    top: 15,
                    right: 15,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        "${_currentImageIndex + 1}/${images.length}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

          if (postType != 'auto_reel' && images.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (index) => Container(
                  margin: const EdgeInsets.only(top: 8, left: 3, right: 3),
                  width: _currentImageIndex == index ? 8 : 6,
                  height: _currentImageIndex == index ? 8 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? const Color(0xFFFD1D1D)
                        : Colors.grey.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),

          Row(
            children: [
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked
                      ? Colors.red
                      : (isDark ? Colors.white : Colors.black),
                ),
                onPressed: _handleLike,
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(widget.post['postId'])
                    .collection('comments')
                    .snapshots(),
                builder: (context, snapshot) {
                  int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.comment_outlined,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CommentsScreen(
                              postId: widget.post['postId'],
                              postOwnerId: widget.post['ownerId'],
                              // 🌟 ఇక్కడే ఎర్రర్ ఉండేది, దాన్ని తీసేసాం.
                            ),
                          ),
                        ),
                      ),
                      if (count > 0)
                        Text(
                          "$count",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                    ],
                  );
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.send_outlined,
                  color: isDark ? Colors.white : Colors.black,
                ),
                onPressed: _showShareMenu,
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: isDark ? Colors.white : Colors.black,
                ),
                onPressed: _handleSave,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: GestureDetector(
              onTap: () {
                List<String> likers = List<String>.from(
                  widget.post['likes'] ?? [],
                );
                if (likers.isNotEmpty)
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          UserListScreen(title: "Likes", userIds: likers),
                    ),
                  );
              },
              child: Text(
                "$likeCount likes",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (widget.post['caption'] != null &&
              widget.post['caption'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: Text(
                widget.post['caption'].toString(),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 14,
                ),
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class AutoReelPlayerForFeed extends StatefulWidget {
  final List<String> imageUrls;
  final String audioUrl;
  final VoidCallback onDoubleTap;

  const AutoReelPlayerForFeed({
    super.key,
    required this.imageUrls,
    required this.audioUrl,
    required this.onDoubleTap,
  });

  @override
  State<AutoReelPlayerForFeed> createState() => _AutoReelPlayerForFeedState();
}

class _AutoReelPlayerForFeedState extends State<AutoReelPlayerForFeed> {
  late AudioPlayer _audioPlayer;
  int _currentIndex = 0;
  Timer? _timer;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
        android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.gain),
      ),
    );
  }

  void _togglePlay() async {
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      try {
        if (widget.audioUrl.isNotEmpty) {
          await _audioPlayer.setVolume(1.0);
          await _audioPlayer.setReleaseMode(ReleaseMode.loop);
          await _audioPlayer.play(UrlSource(widget.audioUrl));
        }
      } catch (e) {}

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 1500), (t) {
        if (mounted && widget.imageUrls.isNotEmpty) {
          setState(() {
            _currentIndex = (_currentIndex + 1) % widget.imageUrls.length;
          });
        }
      });
    } else {
      _timer?.cancel();
      _audioPlayer.pause();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _togglePlay,
      onDoubleTap: widget.onDoubleTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: CachedNetworkImage(
              key: ValueKey<int>(_currentIndex),
              imageUrl: widget.imageUrls[_currentIndex],
              fit: BoxFit.cover,
              width: double.infinity,
              height: MediaQuery.of(context).size.width,
              placeholder: (c, u) => Container(
                color: Colors.black12,
                height: MediaQuery.of(context).size.width,
              ),
              errorWidget: (c, u, e) => Container(
                color: Colors.black12,
                height: MediaQuery.of(context).size.width,
                child: const Icon(Icons.broken_image),
              ),
            ),
          ),
          if (!_isPlaying)
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 40,
              ),
            ),
          if (_isPlaying)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.music_note, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      "Auto-Sync Audio",
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
