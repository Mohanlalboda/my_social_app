import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MySocialApp());
}

class MySocialApp extends StatefulWidget {
  const MySocialApp({super.key});
  @override
  State<MySocialApp> createState() => _MySocialAppState();
}

class _MySocialAppState extends State<MySocialApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
      ),
      darkTheme: ThemeData(brightness: Brightness.dark),
      themeMode: _themeMode,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return MainNavigation(toggleTheme: _toggleTheme);
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final VoidCallback toggleTheme;
  const MainNavigation({super.key, required this.toggleTheme});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      const SearchScreen(),
      const ReelsScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Instagram",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ActivityScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const InboxScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library),
            label: "Reels",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

class PostWidget extends StatefulWidget {
  final Map<String, dynamic> post;
  const PostWidget({super.key, required this.post});

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  bool isLikeAnimating = false;

  void _showComments(BuildContext context, String postId) {
    final TextEditingController commentController = TextEditingController();
    final String currentUid = FirebaseAuth.instance.currentUser!.uid;
    final String currentEmail = FirebaseAuth.instance.currentUser!.email!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 15,
            right: 15,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Comments",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const Divider(),
              SizedBox(
                height: 300,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .doc(postId)
                      .collection('comments')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    if (snapshot.data!.docs.isEmpty)
                      return const Center(
                        child: Text("No comments yet. Be the first!"),
                      );

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var commentDoc = snapshot.data!.docs[index];
                        var comment = commentDoc.data() as Map<String, dynamic>;
                        String commentId = commentDoc.id;
                        bool isMyComment = comment['uid'] == currentUid;

                        String commentTime = "";
                        if (comment['timestamp'] != null) {
                          commentTime = timeago.format(
                            (comment['timestamp'] as Timestamp).toDate(),
                            locale: 'en_short',
                          );
                        }

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 15,
                            child: Text(
                              comment['username'][0].toUpperCase(),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                comment['username'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                commentTime,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(comment['text']),
                          trailing: isMyComment
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        size: 20,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () {
                                        TextEditingController editController =
                                            TextEditingController(
                                              text: comment['text'],
                                            );
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            return AlertDialog(
                                              title: const Text("Edit Comment"),
                                              content: TextField(
                                                controller: editController,
                                                decoration:
                                                    const InputDecoration(
                                                      border:
                                                          OutlineInputBorder(),
                                                    ),
                                                maxLines: 2,
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: const Text("Cancel"),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () async {
                                                    if (editController
                                                        .text
                                                        .isNotEmpty) {
                                                      await FirebaseFirestore
                                                          .instance
                                                          .collection('posts')
                                                          .doc(postId)
                                                          .collection(
                                                            'comments',
                                                          )
                                                          .doc(commentId)
                                                          .update({
                                                            "text":
                                                                editController
                                                                    .text
                                                                    .trim(),
                                                          });
                                                      if (!context.mounted)
                                                        return;
                                                      Navigator.pop(context);
                                                    }
                                                  },
                                                  child: const Text("Save"),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: Colors.red,
                                      ),
                                      onPressed: () async {
                                        await FirebaseFirestore.instance
                                            .collection('posts')
                                            .doc(postId)
                                            .collection('comments')
                                            .doc(commentId)
                                            .delete();
                                        await FirebaseFirestore.instance
                                            .collection('posts')
                                            .doc(postId)
                                            .update({
                                              "commentCount":
                                                  FieldValue.increment(-1),
                                            });
                                      },
                                    ),
                                  ],
                                )
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
              TextField(
                controller: commentController,
                decoration: InputDecoration(
                  hintText: "Add a comment...",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send, color: Colors.blue),
                    onPressed: () async {
                      if (commentController.text.isNotEmpty) {
                        await FirebaseFirestore.instance
                            .collection('posts')
                            .doc(postId)
                            .collection('comments')
                            .add({
                              "text": commentController.text.trim(),
                              "username": currentEmail.split('@')[0],
                              "timestamp": FieldValue.serverTimestamp(),
                              "uid": currentUid,
                            });
                        await FirebaseFirestore.instance
                            .collection('posts')
                            .doc(postId)
                            .update({"commentCount": FieldValue.increment(1)});

                        if (widget.post['ownerId'] != currentUid) {
                          await FirebaseFirestore.instance
                              .collection('notifications')
                              .add({
                                "receiverId": widget.post['ownerId'],
                                "senderId": currentUid,
                                "senderName": currentEmail.split('@')[0],
                                "type": "comment",
                                "timestamp": FieldValue.serverTimestamp(),
                              });
                        }
                        commentController.clear();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _deletePost(BuildContext context, String postId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Post"),
          content: const Text("Are you sure you want to delete this post?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('posts')
                    .doc(postId)
                    .delete();
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Post Deleted 🗑️")),
                );
              },
              child: const Text(
                "Delete",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleLike() async {
    String postId = widget.post['postId'];
    String currentUid = FirebaseAuth.instance.currentUser!.uid;
    String currentEmail = FirebaseAuth.instance.currentUser!.email!;
    bool isLiked =
        widget.post['likes'] != null &&
        widget.post['likes'][currentUid] == true;

    if (!isLiked) {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        "likes.$currentUid": true,
      });
      if (widget.post['ownerId'] != currentUid) {
        await FirebaseFirestore.instance.collection('notifications').add({
          "receiverId": widget.post['ownerId'],
          "senderId": currentUid,
          "senderName": currentEmail.split('@')[0],
          "type": "like",
          "timestamp": FieldValue.serverTimestamp(),
        });
      }
    } else {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        "likes.$currentUid": FieldValue.delete(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String postId = widget.post['postId'];
    String currentUid = FirebaseAuth.instance.currentUser!.uid;
    bool isLiked =
        widget.post['likes'] != null &&
        widget.post['likes'][currentUid] == true;
    int likeCount = widget.post['likes'] != null
        ? (widget.post['likes'] as Map).length
        : 0;
    int commentCount = widget.post['commentCount'] ?? 0;
    String caption = widget.post['caption'] ?? "";

    // 👇 ప్రైవేట్ పోస్ట్ అయితే లాక్ సింబల్ చూపిస్తాం
    bool isPrivate = widget.post['isPrivate'] ?? false;

    List savedBy = widget.post['savedBy'] ?? [];
    bool isSaved = savedBy.contains(currentUid);

    String timeAgo = "Just now";
    if (widget.post['timestamp'] != null) {
      timeAgo = timeago.format(
        (widget.post['timestamp'] as Timestamp).toDate(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: CircleAvatar(
            child: Text(widget.post['username'][0].toUpperCase()),
          ),
          title: Row(
            children: [
              Text(
                widget.post['username'] ?? "User",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (isPrivate) ...[
                const SizedBox(width: 5),
                const Icon(
                  Icons.lock,
                  size: 14,
                  color: Colors.grey,
                ), // లాక్ ఐకాన్
              ],
            ],
          ),
          subtitle: Text(
            timeAgo,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          trailing: widget.post['ownerId'] == currentUid
              ? IconButton(
                  icon: const Icon(Icons.delete, color: Colors.grey),
                  onPressed: () => _deletePost(context, postId),
                )
              : null,
          onTap: () {
            if (widget.post['ownerId'] != currentUid) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      OtherUserProfileScreen(uid: widget.post['ownerId']),
                ),
              );
            }
          },
        ),

        GestureDetector(
          onDoubleTap: () async {
            if (!isLiked) _handleLike();
            setState(() => isLikeAnimating = true);
            await Future.delayed(const Duration(milliseconds: 800));
            if (mounted) setState(() => isLikeAnimating = false);
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.memory(
                base64Decode(widget.post['postData']),
                height: 400,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              AnimatedOpacity(
                opacity: isLikeAnimating ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: AnimatedScale(
                  scale: isLikeAnimating ? 1.2 : 0.5,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: 120,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 20)],
                  ),
                ),
              ),
            ],
          ),
        ),

        Row(
          children: [
            IconButton(
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? Colors.red : null,
              ),
              onPressed: _handleLike,
            ),
            Text(
              "$likeCount",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 15),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () => _showComments(context, postId),
            ),
            Text(
              "$commentCount",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(
                isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: isSaved ? Colors.black : Colors.grey,
              ),
              onPressed: () {
                if (isSaved) {
                  FirebaseFirestore.instance
                      .collection('posts')
                      .doc(postId)
                      .update({
                        "savedBy": FieldValue.arrayRemove([currentUid]),
                      });
                } else {
                  FirebaseFirestore.instance
                      .collection('posts')
                      .doc(postId)
                      .update({
                        "savedBy": FieldValue.arrayUnion([currentUid]),
                      });
                }
              },
            ),
          ],
        ),
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(
                    text: "${widget.post['username']} ",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: caption),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        const Divider(),
      ],
    );
  }
}

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    String currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Notifications",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('receiverId', isEqualTo: currentUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No new notifications 🔔",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          var docs = snapshot.data!.docs;
          docs.sort((a, b) {
            Timestamp? tA =
                (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            Timestamp? tB =
                (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            if (tA == null || tB == null) return 0;
            return tB.compareTo(tA);
          });

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var notif = docs[index].data() as Map<String, dynamic>;
              String type = notif['type'] ?? "";
              String senderName = notif['senderName'] ?? "Someone";

              String timeAgo = "";
              if (notif['timestamp'] != null) {
                timeAgo = timeago.format(
                  (notif['timestamp'] as Timestamp).toDate(),
                  locale: 'en_short',
                );
              }

              String message = "";
              IconData icon = Icons.notifications;
              Color iconColor = Colors.blue;

              if (type == 'like') {
                message = "liked your post.";
                icon = Icons.favorite;
                iconColor = Colors.red;
              } else if (type == 'comment') {
                message = "commented on your post.";
                icon = Icons.comment;
                iconColor = Colors.green;
              } else if (type == 'follow') {
                message = "started following you.";
                icon = Icons.person_add;
                iconColor = Colors.blue;
              }

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[200],
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                title: RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      TextSpan(
                        text: "$senderName ",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: message),
                    ],
                  ),
                ),
                trailing: Text(
                  timeAgo,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class StoryScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const StoryScreen({super.key, required this.user});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _controller.addListener(() => setState(() {}));
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) Navigator.pop(context);
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String profilePic = widget.user['profilePic'] ?? "";
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: profilePic.isNotEmpty
                  ? Image.memory(
                      base64Decode(profilePic),
                      fit: BoxFit.contain,
                      width: double.infinity,
                    )
                  : const Icon(Icons.person, size: 200, color: Colors.white),
            ),
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _controller.value,
                  backgroundColor: Colors.grey[800],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            Positioned(
              top: 30,
              left: 10,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey,
                    backgroundImage: profilePic.isNotEmpty
                        ? MemoryImage(base64Decode(profilePic))
                        : null,
                    child: profilePic.isEmpty
                        ? Text(
                            widget.user['username'][0].toUpperCase(),
                            style: const TextStyle(color: Colors.black),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.user['username'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 30,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isUploading = false;

  Future<void> _uploadPost() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 15,
      maxWidth: 600,
    );

    if (image != null) {
      TextEditingController captionController = TextEditingController();
      bool isPrivatePost = false; // 👇 పబ్లిక్/ప్రైవేట్ కి లాజిక్

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          // State అప్‌డేట్ అవ్వడానికి StatefulBuilder వాడాం
          return StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                title: const Text("New Post"),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.file(
                        File(image.path),
                        height: 150,
                        fit: BoxFit.cover,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: captionController,
                        decoration: const InputDecoration(
                          hintText: "Write a caption...",
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 10),
                      // 👇 NEW: ప్రైవేట్ పోస్ట్ స్విచ్
                      SwitchListTile(
                        title: const Text(
                          "Share only with Followers",
                          style: TextStyle(fontSize: 14),
                        ),
                        value: isPrivatePost,
                        activeColor: Colors.blue,
                        onChanged: (val) {
                          setStateDialog(() {
                            isPrivatePost = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      setState(() => _isUploading = true);
                      try {
                        File imageFile = File(image.path);
                        String base64Image = base64Encode(
                          await imageFile.readAsBytes(),
                        );
                        String uid = FirebaseAuth.instance.currentUser!.uid;
                        String postId = DateTime.now().millisecondsSinceEpoch
                            .toString();

                        await FirebaseFirestore.instance
                            .collection('posts')
                            .doc(postId)
                            .set({
                              "postId": postId,
                              "ownerId": uid,
                              "postData": base64Image,
                              "caption": captionController.text.trim(),
                              "username": FirebaseAuth
                                  .instance
                                  .currentUser!
                                  .email!
                                  .split('@')[0],
                              "timestamp": FieldValue.serverTimestamp(),
                              "likes": {},
                              "commentCount": 0,
                              "savedBy": [],
                              "isPrivate":
                                  isPrivatePost, // 👈 డేటాబేస్ లోకి వెళ్లిపోతుంది
                            });

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Shared! 🌎")),
                        );
                      } catch (e) {
                        debugPrint("Error: $e");
                      } finally {
                        if (mounted) setState(() => _isUploading = false);
                      }
                    },
                    child: const Text("Share"),
                  ),
                ],
              );
            },
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadPost,
        child: const Icon(Icons.add_a_photo),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          var userData =
              userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          List following = userData['following'] ?? [];
          List feedUserIds = List.from(following)..add(currentUid);

          return Column(
            children: [
              SizedBox(
                height: 110,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();

                    var storyUsers = snapshot.data!.docs
                        .where((doc) => feedUserIds.contains(doc['uid']))
                        .toList();

                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: storyUsers.length,
                      itemBuilder: (context, index) {
                        var user =
                            storyUsers[index].data() as Map<String, dynamic>;
                        String profilePic = user['profilePic'] ?? "";
                        String username = user['username'] ?? "User";

                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StoryScreen(user: user),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 35,
                                  backgroundColor: Colors.pink,
                                  child: CircleAvatar(
                                    radius: 32,
                                    backgroundColor: Colors.grey[300],
                                    backgroundImage: profilePic.isNotEmpty
                                        ? MemoryImage(base64Decode(profilePic))
                                        : null,
                                    child: profilePic.isEmpty
                                        ? Text(
                                            username[0].toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.black,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  username.length > 10
                                      ? "${username.substring(0, 8)}..."
                                      : username,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _isUploading
                    ? const Center(child: CircularProgressIndicator())
                    : StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('posts')
                            .orderBy('timestamp', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData)
                            return const Center(
                              child: CircularProgressIndicator(),
                            );

                          var feedPosts = snapshot.data!.docs.where((doc) {
                            return feedUserIds.contains(doc['ownerId']);
                          }).toList();

                          if (feedPosts.isEmpty) {
                            return const Center(
                              child: Text(
                                "Follow people to see their posts here! 🌎",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: feedPosts.length,
                            itemBuilder: (context, index) {
                              var post =
                                  feedPosts[index].data()
                                      as Map<String, dynamic>;
                              return PostWidget(post: post);
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class UsersListScreen extends StatelessWidget {
  final String title;
  final List<dynamic> userIds;

  const UsersListScreen({
    super.key,
    required this.title,
    required this.userIds,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: userIds.isEmpty
          ? const Center(
              child: Text(
                "No users found.",
                style: TextStyle(color: Colors.grey),
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                var users = snapshot.data!.docs
                    .where((doc) => userIds.contains(doc['uid']))
                    .toList();
                if (users.isEmpty)
                  return const Center(child: Text("No users found."));

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    var user = users[index].data() as Map<String, dynamic>;
                    String profilePic = user['profilePic'] ?? "";

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[300],
                        backgroundImage: profilePic.isNotEmpty
                            ? MemoryImage(base64Decode(profilePic))
                            : null,
                        child: profilePic.isEmpty
                            ? Text(
                                user['username'][0].toUpperCase(),
                                style: const TextStyle(color: Colors.black),
                              )
                            : null,
                      ),
                      title: Text(
                        user['username'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(user['bio'] ?? ""),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              OtherUserProfileScreen(uid: user['uid']),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  bool _isUploadingPic = false;

  void _showEditDialog(String currentName, String currentBio) {
    _nameController.text = currentName;
    _bioController.text = currentBio;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Profile"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              TextField(
                controller: _bioController,
                decoration: const InputDecoration(labelText: "Bio"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                String uid = FirebaseAuth.instance.currentUser!.uid;
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update({
                      "username": _nameController.text.trim(),
                      "bio": _bioController.text.trim(),
                    });
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadProfilePic() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 10,
      maxWidth: 200,
    );

    if (image != null) {
      setState(() => _isUploadingPic = true);
      try {
        File imageFile = File(image.path);
        String base64Image = base64Encode(await imageFile.readAsBytes());
        String uid = FirebaseAuth.instance.currentUser!.uid;
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          "profilePic": base64Image,
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile Photo Updated! 📸")),
        );
      } catch (e) {
        debugPrint("Error: $e");
      } finally {
        if (mounted) setState(() => _isUploadingPic = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;
    return DefaultTabController(
      length: 2,
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());

          var userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          String name = userData['username'] ?? "User";
          String bio = userData['bio'] ?? "";
          String profilePic = userData['profilePic'] ?? "";
          List followers = userData['followers'] ?? [];
          List following = userData['following'] ?? [];

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where('ownerId', isEqualTo: uid)
                .snapshots(),
            builder: (context, postSnapshot) {
              int postCount = postSnapshot.hasData
                  ? postSnapshot.data!.docs.length
                  : 0;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _uploadProfilePic,
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: profilePic.isNotEmpty
                                ? MemoryImage(base64Decode(profilePic))
                                : null,
                            child: profilePic.isEmpty
                                ? (_isUploadingPic
                                      ? const CircularProgressIndicator()
                                      : Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : "U",
                                          style: const TextStyle(
                                            fontSize: 24,
                                            color: Colors.black,
                                          ),
                                        ))
                                : null,
                          ),
                        ),
                        const SizedBox(width: 20),

                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    "$postCount",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const Text("Posts"),
                                ],
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UsersListScreen(
                                      title: "Followers",
                                      userIds: followers,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      "${followers.length}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const Text("Followers"),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UsersListScreen(
                                      title: "Following",
                                      userIds: following,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      "${following.length}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const Text("Following"),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(bio, style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _showEditDialog(name, bio),
                        child: const Text(
                          "Edit Profile",
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                  ),
                  const Divider(),

                  const TabBar(
                    indicatorColor: Colors.blue,
                    labelColor: Colors.blue,
                    unselectedLabelColor: Colors.grey,
                    tabs: [
                      Tab(icon: Icon(Icons.grid_on)),
                      Tab(icon: Icon(Icons.bookmark_border)),
                    ],
                  ),

                  Expanded(
                    child: TabBarView(
                      children: [
                        postCount == 0
                            ? const Center(child: Text("No posts yet 📸"))
                            : GridView.builder(
                                padding: const EdgeInsets.all(2),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 2,
                                      mainAxisSpacing: 2,
                                    ),
                                itemCount: postSnapshot.data!.docs.length,
                                itemBuilder: (context, index) {
                                  var post =
                                      postSnapshot.data!.docs[index].data()
                                          as Map<String, dynamic>;
                                  return GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PostDetailsScreen(
                                          postId: post['postId'],
                                        ),
                                      ),
                                    ),
                                    child: Image.memory(
                                      base64Decode(post['postData']),
                                      fit: BoxFit.cover,
                                    ),
                                  );
                                },
                              ),

                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('posts')
                              .where('savedBy', arrayContains: uid)
                              .snapshots(),
                          builder: (context, savedSnapshot) {
                            if (!savedSnapshot.hasData)
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            if (savedSnapshot.data!.docs.isEmpty)
                              return const Center(
                                child: Text("No saved posts yet 🔖"),
                              );
                            return GridView.builder(
                              padding: const EdgeInsets.all(2),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 2,
                                    mainAxisSpacing: 2,
                                  ),
                              itemCount: savedSnapshot.data!.docs.length,
                              itemBuilder: (context, index) {
                                var post =
                                    savedSnapshot.data!.docs[index].data()
                                        as Map<String, dynamic>;
                                return GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PostDetailsScreen(
                                        postId: post['postId'],
                                      ),
                                    ),
                                  ),
                                  child: Image.memory(
                                    base64Decode(post['postData']),
                                    fit: BoxFit.cover,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class OtherUserProfileScreen extends StatelessWidget {
  final String uid;
  const OtherUserProfileScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser!.uid;
    final String currentEmail = FirebaseAuth.instance.currentUser!.email!;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Profile",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || !snapshot.data!.exists)
            return const Center(child: Text("User not found"));

          var userData = snapshot.data!.data() as Map<String, dynamic>;
          String name = userData['username'] ?? "User";
          String bio = userData['bio'] ?? "";
          String profilePic = userData['profilePic'] ?? "";
          List followers = userData['followers'] ?? [];
          List following = userData['following'] ?? [];
          bool isFollowing = followers.contains(currentUid);

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where('ownerId', isEqualTo: uid)
                .snapshots(),
            builder: (context, postSnapshot) {
              // 👇 NEW: ప్రైవేట్ పోస్టులను ఫిల్టర్ చేయడం (ఫాలో అవ్వకపోతే అవి కనపడవు)
              var visiblePosts = postSnapshot.hasData
                  ? postSnapshot.data!.docs.where((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      if (isFollowing)
                        return true; // ఫాలో అయితే అన్నీ చూపిస్తుంది
                      return data['isPrivate'] !=
                          true; // లేదంటే పబ్లిక్ పోస్టులు మాత్రమే చూపిస్తుంది
                    }).toList()
                  : [];

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: profilePic.isNotEmpty
                              ? MemoryImage(base64Decode(profilePic))
                              : null,
                          child: profilePic.isEmpty
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : "U",
                                  style: const TextStyle(
                                    fontSize: 24,
                                    color: Colors.black,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    "${visiblePosts.length}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const Text("Posts"),
                                ],
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UsersListScreen(
                                      title: "Followers",
                                      userIds: followers,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      "${followers.length}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const Text("Followers"),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UsersListScreen(
                                      title: "Following",
                                      userIds: following,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      "${following.length}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const Text("Following"),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(bio, style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFollowing
                                  ? Colors.grey[300]
                                  : Colors.blue,
                              foregroundColor: isFollowing
                                  ? Colors.black
                                  : Colors.white,
                            ),
                            onPressed: () async {
                              if (isFollowing) {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid)
                                    .update({
                                      'followers': FieldValue.arrayRemove([
                                        currentUid,
                                      ]),
                                    });
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(currentUid)
                                    .update({
                                      'following': FieldValue.arrayRemove([
                                        uid,
                                      ]),
                                    });
                              } else {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid)
                                    .update({
                                      'followers': FieldValue.arrayUnion([
                                        currentUid,
                                      ]),
                                    });
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(currentUid)
                                    .update({
                                      'following': FieldValue.arrayUnion([uid]),
                                    });

                                await FirebaseFirestore.instance
                                    .collection('notifications')
                                    .add({
                                      "receiverId": uid,
                                      "senderId": currentUid,
                                      "senderName": currentEmail.split('@')[0],
                                      "type": "follow",
                                      "timestamp": FieldValue.serverTimestamp(),
                                    });
                              }
                            },
                            child: Text(isFollowing ? "Unfollow" : "Follow"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  receiverId: uid,
                                  receiverName: name,
                                ),
                              ),
                            ),
                            child: const Text(
                              "Message",
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),

                  Expanded(
                    child: visiblePosts.isEmpty
                        ? Center(
                            child: Text(
                              isFollowing
                                  ? "No posts yet 📸"
                                  : "Private posts hidden 🔒",
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(2),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 2,
                                  mainAxisSpacing: 2,
                                ),
                            itemCount: visiblePosts.length,
                            itemBuilder: (context, index) {
                              var post =
                                  visiblePosts[index].data()
                                      as Map<String, dynamic>;
                              return GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PostDetailsScreen(
                                      postId: post['postId'],
                                    ),
                                  ),
                                ),
                                child: Image.memory(
                                  base64Decode(post['postData']),
                                  fit: BoxFit.cover,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class PostDetailsScreen extends StatelessWidget {
  final String postId;
  const PostDetailsScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Post")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || !snapshot.data!.exists)
            return const Center(child: Text("Post not found"));

          var post = snapshot.data!.data() as Map<String, dynamic>;
          return SingleChildScrollView(child: PostWidget(post: post));
        },
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _searchName = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: const InputDecoration(
            hintText: "Search users...",
            prefixIcon: Icon(Icons.search),
            border: InputBorder.none,
          ),
          onChanged: (val) => setState(() => _searchName = val.toLowerCase()),
        ),
      ),
      body: _searchName.isEmpty
          ? StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                // 👇 NEW: పబ్లిక్ పోస్టులు మాత్రమే ఎక్స్‌ప్లోర్ పేజీలో కనిపిస్తాయి!
                var publicPosts = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return data['isPrivate'] != true;
                }).toList();

                if (publicPosts.isEmpty)
                  return const Center(
                    child: Text("No posts to explore yet! 🌎"),
                  );

                return GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  itemCount: publicPosts.length,
                  itemBuilder: (context, index) {
                    var post =
                        publicPosts[index].data() as Map<String, dynamic>;
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PostDetailsScreen(postId: post['postId']),
                        ),
                      ),
                      child: Image.memory(
                        base64Decode(post['postData']),
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                );
              },
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                  return const Center(child: Text("No users found"));

                var filteredUsers = snapshot.data!.docs.where((doc) {
                  String username = doc['username'].toString().toLowerCase();
                  return username.contains(_searchName);
                }).toList();

                return ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    var user =
                        filteredUsers[index].data() as Map<String, dynamic>;
                    if (user['uid'] == FirebaseAuth.instance.currentUser!.uid)
                      return const SizedBox.shrink();

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[300],
                        backgroundImage:
                            (user['profilePic'] != null &&
                                user['profilePic'].toString().isNotEmpty)
                            ? MemoryImage(base64Decode(user['profilePic']))
                            : null,
                        child:
                            (user['profilePic'] == null ||
                                user['profilePic'].toString().isEmpty)
                            ? Text(
                                user['username'][0].toUpperCase(),
                                style: const TextStyle(color: Colors.black),
                              )
                            : null,
                      ),
                      title: Text(
                        user['username'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(user['bio'] ?? ""),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              OtherUserProfileScreen(uid: user['uid']),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Messages",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
            return const Center(child: Text("No messages yet."));

          var usersList = snapshot.data!.docs
              .where((doc) => doc['uid'] != currentUid)
              .toList();

          return ListView.builder(
            itemCount: usersList.length,
            itemBuilder: (context, index) {
              var user = usersList[index].data() as Map<String, dynamic>;
              String profilePic = user['profilePic'] ?? "";

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[300],
                  backgroundImage: profilePic.isNotEmpty
                      ? MemoryImage(base64Decode(profilePic))
                      : null,
                  child: profilePic.isEmpty
                      ? Text(
                          user['username'][0].toUpperCase(),
                          style: const TextStyle(color: Colors.black),
                        )
                      : null,
                ),
                title: Text(
                  user['username'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text("Tap to chat..."),
                trailing: const Icon(
                  Icons.chat_bubble_outline,
                  size: 20,
                  color: Colors.grey,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      receiverId: user['uid'],
                      receiverName: user['username'],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();

  String getChatRoomId(String a, String b) {
    if (a.substring(0, 1).codeUnitAt(0) > b.substring(0, 1).codeUnitAt(0))
      return "${b}_$a";
    return "${a}_$b";
  }

  void _sendMessage() async {
    if (_msgController.text.isNotEmpty) {
      String senderId = FirebaseAuth.instance.currentUser!.uid;
      String roomId = getChatRoomId(senderId, widget.receiverId);

      Map<String, dynamic> messageData = {
        "senderId": senderId,
        "message": _msgController.text.trim(),
        "timestamp": FieldValue.serverTimestamp(),
      };

      _msgController.clear();
      await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(roomId)
          .collection('messages')
          .add(messageData);
    }
  }

  @override
  Widget build(BuildContext context) {
    String currentUid = FirebaseAuth.instance.currentUser!.uid;
    String roomId = getChatRoomId(currentUid, widget.receiverId);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.receiverName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chatRooms')
                  .doc(roomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                return ListView.builder(
                  reverse: true,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var msgDoc = snapshot.data!.docs[index];
                    var msg = msgDoc.data() as Map<String, dynamic>;
                    String msgId = msgDoc.id;
                    bool isMe = msg['senderId'] == currentUid;

                    String msgTime = "";
                    if (msg['timestamp'] != null) {
                      msgTime = timeago.format(
                        (msg['timestamp'] as Timestamp).toDate(),
                        locale: 'en_short',
                      );
                    }

                    return GestureDetector(
                      onLongPress: () {
                        if (isMe) {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text("Unsend Message"),
                                content: const Text(
                                  "Are you sure you want to unsed this message?",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Cancel"),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    onPressed: () async {
                                      await FirebaseFirestore.instance
                                          .collection('chatRooms')
                                          .doc(roomId)
                                          .collection('messages')
                                          .doc(msgId)
                                          .delete();
                                      if (!context.mounted) return;
                                      Navigator.pop(context);
                                    },
                                    child: const Text(
                                      "Unsend",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      },
                      child: Container(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.blue : Colors.grey[300],
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Text(
                                msg['message'],
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              msgTime,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: InputDecoration(
                      hintText: "Message...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
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

class ReelsScreen extends StatelessWidget {
  const ReelsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: 5,
      itemBuilder: (context, index) {
        return const Stack(
          children: [
            SizedBox.expand(
              child: VideoReelItem(
                videoUrl:
                    "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4",
              ),
            ),
            Positioned(
              right: 15,
              bottom: 100,
              child: Column(
                children: [
                  Icon(Icons.favorite, color: Colors.white, size: 35),
                  Text(
                    "1.2k",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 20),
                  Icon(Icons.comment, color: Colors.white, size: 35),
                  Text(
                    "340",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class VideoReelItem extends StatefulWidget {
  final String videoUrl;
  const VideoReelItem({super.key, required this.videoUrl});
  @override
  State<VideoReelItem> createState() => _VideoReelItemState();
}

class _VideoReelItemState extends State<VideoReelItem> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
        _controller.setLooping(true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          )
        : const Center(child: CircularProgressIndicator(color: Colors.white));
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _login() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Instagram Clone",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _login,
                child: const Text("Log In"),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SignUpScreen()),
              ),
              child: const Text("Sign Up"),
            ),
          ],
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  Future<void> _signUp() async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            "username": _usernameController.text.trim(),
            "email": _emailController.text.trim(),
            "uid": userCredential.user!.uid,
            "bio": "Law Student | OU ⚖️",
            "createdAt": DateTime.now(),
            "profilePic": "",
            "followers": [],
            "following": [],
          });
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Account")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: "Username",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _signUp,
                child: const Text("Sign Up"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
