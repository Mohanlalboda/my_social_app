import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

import '../screens/other_user_profile_screen.dart';
import '../screens/comments_screen.dart';

class ReelItem extends StatefulWidget {
  final Map<String, dynamic> reelData;
  const ReelItem({super.key, required this.reelData});

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  bool _isLiked = false;
  int _likeCount = 0;
  bool _showHeartAnimation = false;
  late String currentUid;
  late String reelOwnerId;

  @override
  void initState() {
    super.initState();
    currentUid = FirebaseAuth.instance.currentUser!.uid;
    reelOwnerId = widget.reelData['uid'];

    List likes = widget.reelData['likes'] ?? [];
    _isLiked = likes.contains(currentUid);
    _likeCount = likes.length;

    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.reelData['videoUrl']))
          ..initialize()
              .then((_) {
                if (mounted) {
                  setState(() {
                    _isInitialized = true;
                  });
                  _controller.setLooping(true);
                  _controller.play();
                }
              })
              .catchError((e) {
                debugPrint("🚨 Reel Play Error: $e");
              });
  }

  void _toggleLike() async {
    if (!mounted) return;
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        _likeCount++;
        _showHeartAnimation = true;
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _showHeartAnimation = false);
        });
      } else {
        _likeCount--;
      }
    });

    String reelId = widget.reelData['reelId'];
    try {
      if (_isLiked) {
        await FirebaseFirestore.instance.collection('reels').doc(reelId).update(
          {
            'likes': FieldValue.arrayUnion([currentUid]),
          },
        );
      } else {
        await FirebaseFirestore.instance.collection('reels').doc(reelId).update(
          {
            'likes': FieldValue.arrayRemove([currentUid]),
          },
        );
      }
    } catch (e) {
      debugPrint("🚨 Like Error: $e");
    }
  }

  void _toggleFollow(bool isFollowing) async {
    try {
      if (isFollowing) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(reelOwnerId)
            .update({
              'followers': FieldValue.arrayRemove([currentUid]),
            });
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .update({
              'following': FieldValue.arrayRemove([reelOwnerId]),
            });
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(reelOwnerId)
            .update({
              'followers': FieldValue.arrayUnion([currentUid]),
            });
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .update({
              'following': FieldValue.arrayUnion([reelOwnerId]),
            });
      }
    } catch (e) {
      debugPrint("🚨 Follow Error: $e");
    }
  }

  // 🌟 యాప్ లోని యూజర్స్ కి సెండ్ చేయడానికి మ్యాజిక్ ఫంక్షన్
  void _sendReelToUser(String receiverId, String receiverName) async {
    Navigator.pop(context); // మెనూ క్లోజ్ అవ్వడానికి
    try {
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': currentUid,
        'receiverId': receiverId,
        'text': "🎬 Check out this Reel:\n${widget.reelData['videoUrl']}",
        'type': 'text',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Sent to $receiverName! ✅"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("🚨 Send Error: $e");
    }
  }

  // 🌟 కొత్తగా యాడ్ చేసిన Share Menu (Internal + External)
  void _showShareMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height:
              MediaQuery.of(context).size.height *
              0.6, // స్క్రీన్ లో సగం వస్తుంది
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Share Reel",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // ఎక్స్‌టర్నల్ షేర్ (WhatsApp, Insta కు పంపడానికి)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.share, color: Colors.white),
                ),
                title: const Text(
                  "Share via...",
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // ignore: deprecated_member_use
                  Share.share(
                    "Check out this awesome Reel on MyBanjara App! 🎬\n${widget.reelData['videoUrl']}",
                  );
                },
              ),
              const Divider(color: Colors.white24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Send to App Users",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
              // ఇంటర్నల్ యూజర్స్ లిస్ట్
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    var users = snapshot.data!.docs
                        .where((doc) => doc.id != currentUid)
                        .toList();
                    if (users.isEmpty) {
                      return const Center(
                        child: Text(
                          "No users found",
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        var u = users[index].data() as Map<String, dynamic>;
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.blueGrey,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(
                            u['username'] ?? "User",
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                            onPressed: () => _sendReelToUser(
                              u['uid'],
                              u['username'] ?? "User",
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOptionsDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (currentUid == reelOwnerId) ...[
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blue),
                  title: const Text("Edit Caption"),
                  onTap: () {
                    Navigator.pop(context);
                    _editCaption();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text("Delete Reel"),
                  onTap: () {
                    Navigator.pop(context);
                    FirebaseFirestore.instance
                        .collection('reels')
                        .doc(widget.reelData['reelId'])
                        .delete();
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.report, color: Colors.red),
                  title: const Text("Report"),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _editCaption() {
    TextEditingController editCtrl = TextEditingController(
      text: widget.reelData['caption'],
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Caption"),
        content: TextField(controller: editCtrl, maxLines: 3),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('reels')
                  .doc(widget.reelData['reelId'])
                  .update({'caption': editCtrl.text.trim()});
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
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
        // 📺 1. వీడియో ప్లేయర్
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

        // ⬛ 2. బ్లాక్ షాడో
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: MediaQuery.of(context).size.height * 0.4,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // ⏸️ 3. పాజ్ అయినప్పుడు "Play" సింబల్
        if (!isPlaying && _isInitialized)
          const IgnorePointer(
            child: Center(
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white60,
                size: 100,
              ),
            ),
          ),

        // 💖 4. డబుల్ టాప్ లైక్ యానిమేషన్
        IgnorePointer(
          child: Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _showHeartAnimation ? 1.0 : 0.0,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: _showHeartAnimation ? 1.2 : 0.5,
                curve: Curves.elasticOut,
                child: const Icon(
                  Icons.favorite,
                  color: Colors.white70,
                  size: 120,
                ),
              ),
            ),
          ),
        ),

        // 🔘 5. రైట్ సైడ్ బటన్స్
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

              // 💬 కామెంట్స్ కౌంట్
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('reels')
                    .doc(widget.reelData['reelId'])
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
                            postId: widget.reelData['reelId'],
                            isReel: true,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),

              // ✈️ ఇక్కడే మనం యాడ్ చేసిన ఇంటర్నల్ షేర్ ఫంక్షన్ లింక్ చేసాం
              _buildActionIcon(
                icon: Icons.send_outlined,
                color: Colors.white,
                label: "Share",
                onTap: _showShareMenu,
              ),
              const SizedBox(height: 20),

              // ⚙️ త్రీ డాట్స్
              GestureDetector(
                onTap: _showOptionsDialog,
                child: const Icon(
                  Icons.more_vert,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),

              // మ్యూజిక్ ఐకాన్
              Container(
                height: 35,
                width: 35,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade800,
                ),
                child: const Icon(
                  Icons.music_note,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),

        // ✍️ 6. లెఫ్ట్ సైడ్ యూజర్ డీటెయిల్స్ (🌟 రియల్ టైమ్ డేటా లాగేలా మార్చాం)
        Positioned(
          bottom: 20,
          left: 15,
          right: 80,
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(reelOwnerId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const SizedBox();
              }

              var userData =
                  snapshot.data!.data() as Map<String, dynamic>? ?? {};
              String realUsername =
                  userData['username'] ?? "User"; // 🌟 ఒరిజినల్ యూజర్ నేమ్
              List followers = userData['followers'] ?? [];
              bool isFollowing = followers.contains(currentUid);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              OtherUserProfileScreen(uid: reelOwnerId),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.blueAccent,
                          child: Text(
                            realUsername.isNotEmpty
                                ? realUsername[0].toUpperCase()
                                : "?",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          realUsername,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 10),

                        if (currentUid != reelOwnerId)
                          GestureDetector(
                            onTap: () => _toggleFollow(isFollowing),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                color: isFollowing
                                    ? Colors.transparent
                                    : Colors.blue,
                              ),
                              child: Text(
                                isFollowing ? "Following" : "Follow",
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
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.reelData['caption'] ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.music_note, color: Colors.white, size: 16),
                      SizedBox(width: 5),
                      Text(
                        "Original Audio",
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
