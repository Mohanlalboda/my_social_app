import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
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
      _themeMode = (_themeMode == ThemeMode.light)
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MyBanjara',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFFFD1D1D),
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ),
      ),
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
      const Center(child: Text("Reels coming soon!")),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex == 3
          ? null
          : AppBar(
              title: Text(
                "MyBanjara",
                style: GoogleFonts.lobster(
                  fontSize: 28,
                  color: const Color(0xFFFD1D1D),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.favorite_border),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ActivityScreen(),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.send_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const InboxScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: const Color(0xFFFD1D1D),
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library_outlined),
            label: "Reels",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Profile",
          ),
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
  bool? isSavedLocal;

  void _handleSave() async {
    String postId = widget.post['postId'];
    String currentUid = FirebaseAuth.instance.currentUser!.uid;
    List savedBy = widget.post['savedBy'] ?? [];
    bool isSaved = isSavedLocal ?? savedBy.contains(currentUid);

    setState(() {
      isSavedLocal = !isSaved;
    });

    if (isSaved) {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        "savedBy": FieldValue.arrayRemove([currentUid]),
      });
    } else {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        "savedBy": FieldValue.arrayUnion([currentUid]),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Post Saved to Profile! 📌")),
        );
      }
    }
  }

  Future<void> _shareExternally(Map<String, dynamic> post) async {
    try {
      String cleanString = post['postData'].replaceAll(RegExp(r'\s+'), '');
      String normalized = base64.normalize(cleanString);
      final bytes = base64Decode(normalized);

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/shared_post.png').create();
      await file.writeAsBytes(bytes);

      String shareText =
          'Check out this post from ${post['username']} on MyBanjara!\n\n${post['caption'] ?? ''}';

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: shareText),
      );
    } catch (e) {
      debugPrint('Error sharing to external platforms: $e');
    }
  }

  void _showComments(BuildContext context, String postId) {
    final TextEditingController commentController = TextEditingController();
    final String currentUid = FirebaseAuth.instance.currentUser!.uid;
    final String currentEmail = FirebaseAuth.instance.currentUser!.email!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Comments",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const Divider(),
              SizedBox(
                height: 350,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .doc(postId)
                      .collection('comments')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text("Be the first to comment! ✨"),
                      );
                    }
                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var commentDoc = snapshot.data!.docs[index];
                        var comment = commentDoc.data() as Map<String, dynamic>;
                        String commentId = commentDoc.id;
                        bool isMyComment = comment['uid'] == currentUid;
                        String commentTime = comment['timestamp'] != null
                            ? timeago.format(
                                (comment['timestamp'] as Timestamp).toDate(),
                                locale: 'en_short',
                              )
                            : "";

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            child: Text(comment['username'][0].toUpperCase()),
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
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
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
                                          "commentCount": FieldValue.increment(
                                            -1,
                                          ),
                                        });
                                  },
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
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

  void _showShareSheet(BuildContext context, Map<String, dynamic> post) {
    final String currentUid = FirebaseAuth.instance.currentUser!.uid;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            var users = snapshot.data!.docs
                .where((doc) => doc['uid'] != currentUid)
                .toList();
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(15.0),
                  child: Text(
                    "Share Post",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.share, color: Colors.white),
                  ),
                  title: const Text(
                    "Share via other apps",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                    await _shareExternally(post);
                  },
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 15.0,
                    vertical: 5.0,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Send to Friends",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      var user = users[index].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(user['username'][0].toUpperCase()),
                        ),
                        title: Text(user['username']),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () async {
                            String roomId =
                                (currentUid.hashCode <= user['uid'].hashCode)
                                ? "${currentUid}_${user['uid']}"
                                : "${user['uid']}_$currentUid";

                            await FirebaseFirestore.instance
                                .collection('chatRooms')
                                .doc(roomId)
                                .collection('messages')
                                .add({
                                  "senderId": currentUid,
                                  "message": "Check out this post!",
                                  "postId": post['postId'],
                                  "postImage": post['postData'],
                                  "timestamp": FieldValue.serverTimestamp(),
                                });

                            await FirebaseFirestore.instance
                                .collection('chatRooms')
                                .doc(roomId)
                                .set({
                                  "lastMessage": "Shared a post",
                                  "lastTime": FieldValue.serverTimestamp(),
                                  "users": [currentUid, user['uid']],
                                }, SetOptions(merge: true));

                            if (context.mounted) {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    receiverId: user['uid'],
                                    receiverName: user['username'],
                                  ),
                                ),
                              );
                            }
                          },
                          child: const Text(
                            "Send",
                            style: TextStyle(color: Colors.white),
                          ),
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
    );
  }

  void _handleLike() async {
    String postId = widget.post['postId'];
    String currentUid = FirebaseAuth.instance.currentUser!.uid;
    String currentEmail = FirebaseAuth.instance.currentUser!.email!;
    bool isLiked =
        (widget.post['likes'] != null &&
        widget.post['likes'][currentUid] == true);

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
        (widget.post['likes'] != null &&
        widget.post['likes'][currentUid] == true);

    List savedBy = widget.post['savedBy'] ?? [];
    bool isSaved = isSavedLocal ?? savedBy.contains(currentUid);

    int likeCount = (widget.post['likes'] != null)
        ? (widget.post['likes'] as Map).length
        : 0;
    int commentCount = widget.post['commentCount'] ?? 0;
    bool isPrivate = widget.post['isPrivate'] ?? false;
    String timeAgo = (widget.post['timestamp'] != null)
        ? timeago.format((widget.post['timestamp'] as Timestamp).toDate())
        : "Just now";

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
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
                  const Icon(Icons.lock, size: 14, color: Colors.grey),
                ],
              ],
            ),
            subtitle: Text(timeAgo, style: const TextStyle(fontSize: 12)),
          ),
          GestureDetector(
            onDoubleTap: () async {
              if (!isLiked) {
                _handleLike();
              }
              setState(() {
                isLikeAnimating = true;
              });
              await Future.delayed(const Duration(milliseconds: 800));
              if (mounted) {
                setState(() {
                  isLikeAnimating = false;
                });
              }
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: SafeImage(
                      base64String: widget.post['postData'],
                      height: 400,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: isLikeAnimating ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: 100,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.black87,
                  ),
                  onPressed: _handleLike,
                ),
                Text(
                  "$likeCount",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 15),
                IconButton(
                  icon: const Icon(Icons.mode_comment_outlined),
                  onPressed: () {
                    _showComments(context, postId);
                  },
                ),
                Text(
                  "$commentCount",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.near_me_outlined, size: 28),
                  onPressed: () {
                    _showShareSheet(context, widget.post);
                  },
                ),
                IconButton(
                  icon: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: isSaved ? Colors.black : Colors.black87,
                  ),
                  onPressed: _handleSave,
                ),
              ],
            ),
          ),
          if (widget.post['caption'] != null &&
              widget.post['caption'].isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 15, right: 15, bottom: 15),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: Colors.black,
                    fontFamily: 'Poppins',
                  ),
                  children: [
                    TextSpan(
                      text: "${widget.post['username']} ",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: widget.post['caption']),
                  ],
                ),
              ),
            ),
          ],
        ],
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

  Future<void> _uploadStory() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 15,
      maxWidth: 600,
    );

    if (image != null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isUploading = true;
      });
      try {
        String base64Image = base64Encode(await File(image.path).readAsBytes());
        String uid = FirebaseAuth.instance.currentUser!.uid;

        await FirebaseFirestore.instance.collection('stories').add({
          "ownerId": uid,
          "storyData": base64Image,
          "timestamp": FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Story Added! 🌟")));
        }
      } catch (e) {
        debugPrint(e.toString());
      } finally {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
      }
    }
  }

  Future<void> _uploadPost() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 15,
      maxWidth: 600,
    );

    if (image != null) {
      TextEditingController captionController = TextEditingController();
      bool isPrivatePost = false;
      if (!mounted) {
        return;
      }

      showDialog(
        context: context,
        builder: (context) {
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
                      SwitchListTile(
                        title: const Text("Private Post"),
                        value: isPrivatePost,
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
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (!mounted) {
                        return;
                      }
                      final localContext = context;
                      Navigator.pop(localContext);
                      setState(() {
                        _isUploading = true;
                      });
                      try {
                        String base64Image = base64Encode(
                          await File(image.path).readAsBytes(),
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
                              "isPrivate": isPrivatePost,
                            });
                        if (localContext.mounted) {
                          ScaffoldMessenger.of(localContext).showSnackBar(
                            const SnackBar(content: Text("Shared! 🌎")),
                          );
                        }
                      } catch (e) {
                        debugPrint(e.toString());
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isUploading = false;
                          });
                        }
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
        backgroundColor: const Color(0xFFFD1D1D),
        onPressed: _uploadPost,
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
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
                    if (!snapshot.hasData) {
                      return const SizedBox();
                    }
                    var storyUsers = snapshot.data!.docs
                        .where((doc) => feedUserIds.contains(doc['uid']))
                        .toList();

                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: storyUsers.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return GestureDetector(
                            onTap: _uploadStory,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                children: [
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      SafeProfilePic(
                                        base64String: userData['profilePic'],
                                        radius: 35,
                                        fallbackText:
                                            userData['username'] ?? "U",
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.blue,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.add,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  const Text(
                                    "Your Story",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        var user =
                            storyUsers[index - 1].data()
                                as Map<String, dynamic>;
                        return GestureDetector(
                          onTap: () {
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => StoryScreen(user: user),
                                ),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF833AB4),
                                        Color(0xFFFD1D1D),
                                        Color(0xFFF56040),
                                      ],
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 32,
                                    backgroundColor: Colors.white,
                                    child: SafeProfilePic(
                                      base64String: user['profilePic'],
                                      radius: 30,
                                      fallbackText: user['username'] ?? "U",
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  user['username'],
                                  style: const TextStyle(fontSize: 10),
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
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          var feedPosts = snapshot.data!.docs
                              .where(
                                (doc) => feedUserIds.contains(doc['ownerId']),
                              )
                              .toList();
                          if (feedPosts.isEmpty) {
                            return const Center(
                              child: Text("Follow people to see posts! 🌎"),
                            );
                          }
                          return ListView.builder(
                            itemCount: feedPosts.length,
                            itemBuilder: (context, index) => PostWidget(
                              post:
                                  feedPosts[index].data()
                                      as Map<String, dynamic>,
                            ),
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

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});
  @override
  Widget build(BuildContext context) {
    String currentUid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text("Activity")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('receiverId', isEqualTo: currentUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No notifications yet."));
          }
          var docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var notif = docs[index].data() as Map<String, dynamic>;
              String timeStr = notif['timestamp'] != null
                  ? timeago.format(
                      (notif['timestamp'] as Timestamp).toDate(),
                      locale: 'en_short',
                    )
                  : "";
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.notifications)),
                title: Text(
                  "${notif['senderName'] ?? 'Someone'} ${notif['type']}d your post.",
                ),
                trailing: Text(timeStr),
              );
            },
          );
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
            border: InputBorder.none,
          ),
          onChanged: (val) {
            setState(() {
              _searchName = val.toLowerCase();
            });
          },
        ),
      ),
      body: _searchName.isEmpty
          ? StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var publicPosts = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return data.containsKey('isPrivate')
                      ? data['isPrivate'] != true
                      : true;
                }).toList();

                return GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  itemCount: publicPosts.length,
                  itemBuilder: (context, index) {
                    var postDataMap =
                        publicPosts[index].data() as Map<String, dynamic>;
                    return GestureDetector(
                      onTap: () {
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PostDetailsScreen(
                                postId: publicPosts[index].id,
                              ),
                            ),
                          );
                        }
                      },
                      child: SafeImage(
                        base64String: postDataMap['postData'],
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
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var filtered = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return data.containsKey('username') &&
                      data['username'].toString().toLowerCase().contains(
                        _searchName,
                      );
                }).toList();

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    var userData =
                        filtered[index].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: SafeProfilePic(
                        base64String: userData['profilePic'],
                        radius: 20,
                        fallbackText: userData['username'] ?? "U",
                      ),
                      title: Text(userData['username'] ?? 'User'),
                      onTap: () {
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  OtherUserProfileScreen(uid: userData['uid']),
                            ),
                          );
                        }
                      },
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

  String getChatRoomId(String a, String b) {
    return a.hashCode <= b.hashCode ? "${a}_$b" : "${b}_$a";
  }

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
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var usersList = snapshot.data!.docs
              .where((doc) => doc['uid'] != currentUid)
              .toList();

          return ListView.builder(
            itemCount: usersList.length,
            itemBuilder: (context, index) {
              var user = usersList[index].data() as Map<String, dynamic>;
              String roomId = getChatRoomId(currentUid, user['uid']);

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chatRooms')
                    .doc(roomId)
                    .snapshots(),
                builder: (context, roomSnapshot) {
                  String lastMsg = "Tap to chat";
                  String lastTime = "";

                  if (roomSnapshot.hasData && roomSnapshot.data!.exists) {
                    var roomData =
                        roomSnapshot.data!.data() as Map<String, dynamic>;
                    lastMsg = roomData['lastMessage'] ?? "Tap to chat";
                    if (roomData['lastTime'] != null) {
                      lastTime = timeago.format(
                        (roomData['lastTime'] as Timestamp).toDate(),
                        locale: 'en_short',
                      );
                    }
                  }

                  return ListTile(
                    leading: SafeProfilePic(
                      base64String: user['profilePic'],
                      radius: 25,
                      fallbackText: user['username'] ?? "U",
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          user['username'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          lastTime,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      lastMsg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              receiverId: user['uid'],
                              receiverName: user['username'],
                            ),
                          ),
                        );
                      }
                    },
                  );
                },
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
    return a.hashCode <= b.hashCode ? "${a}_$b" : "${b}_$a";
  }

  void _sendMessage() async {
    if (_msgController.text.trim().isNotEmpty) {
      String senderId = FirebaseAuth.instance.currentUser!.uid;
      String roomId = getChatRoomId(senderId, widget.receiverId);
      String msg = _msgController.text.trim();
      _msgController.clear();

      await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(roomId)
          .collection('messages')
          .add({
            "senderId": senderId,
            "message": msg,
            "timestamp": FieldValue.serverTimestamp(),
          });

      await FirebaseFirestore.instance.collection('chatRooms').doc(roomId).set({
        "lastMessage": msg,
        "lastTime": FieldValue.serverTimestamp(),
        "users": [senderId, widget.receiverId],
      }, SetOptions(merge: true));
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
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var docs = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    bool isMe = data['senderId'] == currentUid;
                    String timeStr = data['timestamp'] != null
                        ? timeago.format(
                            (data['timestamp'] as Timestamp).toDate(),
                            locale: 'en_short',
                          )
                        : "";

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (data.containsKey('postId')) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PostDetailsScreen(
                                      postId: data['postId'],
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 10,
                              ),
                              padding: const EdgeInsets.all(12),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.7,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? Colors.indigoAccent
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(15),
                                  topRight: const Radius.circular(15),
                                  bottomLeft: isMe
                                      ? const Radius.circular(15)
                                      : const Radius.circular(0),
                                  bottomRight: isMe
                                      ? const Radius.circular(0)
                                      : const Radius.circular(15),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (data.containsKey('postImage') &&
                                      data['postImage'] != null) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SafeImage(
                                        base64String: data['postImage'],
                                        height: 180,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                  ],
                                  Text(
                                    data['message'],
                                    style: TextStyle(
                                      color: isMe ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            child: Text(
                              timeStr,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
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
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.indigoAccent),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
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
  void _showEditDialog(String currentName, String currentBio) {
    final nameCtrl = TextEditingController(text: currentName);
    final bioCtrl = TextEditingController(text: currentBio);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Profile"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            TextField(
              controller: bioCtrl,
              decoration: const InputDecoration(labelText: "Bio"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              String uid = FirebaseAuth.instance.currentUser!.uid;
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .update({
                    "username": nameCtrl.text.trim(),
                    "bio": bioCtrl.text.trim(),
                  });
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProfilePic() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 10,
      maxWidth: 300,
    );
    if (image != null) {
      String base64Image = base64Encode(await File(image.path).readAsBytes());
      String uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        "profilePic": base64Image,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Profile updated! 📸")));
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
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          String name = userData['username'] ?? "User";
          String bio = userData['bio'] ?? "No bio yet.";

          return Scaffold(
            appBar: AppBar(
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.menu),
                  onSelected: (value) {
                    if (value == 'pic') {
                      _updateProfilePic();
                    } else if (value == 'logout') {
                      FirebaseAuth.instance.signOut();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'pic',
                      child: Row(
                        children: [
                          Icon(Icons.camera_alt_outlined),
                          SizedBox(width: 10),
                          Text("Change Profile Pic"),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Colors.red),
                          SizedBox(width: 10),
                          Text("Logout", style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .where('ownerId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, postSnapshot) {
                int postCount = postSnapshot.hasData
                    ? postSnapshot.data!.docs.length
                    : 0;
                List followers = userData['followers'] ?? [];
                List following = userData['following'] ?? [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      child: Row(
                        children: [
                          SafeProfilePic(
                            base64String: userData['profilePic'],
                            radius: 40,
                            fallbackText: name,
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStatColumn(postCount, "Posts"),
                                _buildStatColumn(followers.length, "Followers"),
                                _buildStatColumn(following.length, "Following"),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                          Text(bio),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            _showEditDialog(name, bio);
                          },
                          child: const Text("Edit Profile"),
                        ),
                      ),
                    ),
                    const TabBar(
                      indicatorColor: Colors.black,
                      labelColor: Colors.black,
                      tabs: [
                        Tab(icon: Icon(Icons.grid_on)),
                        Tab(icon: Icon(Icons.bookmark_border)),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          postCount == 0
                              ? const Center(child: Text("No posts yet!"))
                              : GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        crossAxisSpacing: 2,
                                        mainAxisSpacing: 2,
                                      ),
                                  itemCount: postCount,
                                  itemBuilder: (context, index) {
                                    var post =
                                        postSnapshot.data!.docs[index].data()
                                            as Map<String, dynamic>;
                                    return GestureDetector(
                                      onTap: () {
                                        if (context.mounted) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  PostDetailsScreen(
                                                    postId: post['postId'],
                                                  ),
                                            ),
                                          );
                                        }
                                      },
                                      child: SafeImage(
                                        base64String: post['postData'],
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
                              if (!savedSnapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              var savedPosts = savedSnapshot.data!.docs;
                              if (savedPosts.isEmpty) {
                                return const Center(
                                  child: Text(
                                    "No saved posts yet 📌",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                );
                              }
                              return GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 2,
                                      mainAxisSpacing: 2,
                                    ),
                                itemCount: savedPosts.length,
                                itemBuilder: (context, index) {
                                  var post =
                                      savedPosts[index].data()
                                          as Map<String, dynamic>;
                                  return GestureDetector(
                                    onTap: () {
                                      if (context.mounted) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                PostDetailsScreen(
                                                  postId: post['postId'],
                                                ),
                                          ),
                                        );
                                      }
                                    },
                                    child: SafeImage(
                                      base64String: post['postData'],
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
            ),
          );
        },
      ),
    );
  }

  Column _buildStatColumn(int num, String label) {
    return Column(
      children: [
        Text(
          num.toString(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
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
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text("Post deleted or not found."));
          }
          return SingleChildScrollView(
            child: PostWidget(
              post: snapshot.data!.data() as Map<String, dynamic>,
            ),
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
    _controller.addListener(() {
      setState(() {});
    });
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.pop(context);
      }
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('stories')
              .where('ownerId', isEqualTo: widget.user['uid'])
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            var docs = snapshot.data!.docs;
            docs.sort((a, b) {
              Timestamp t1 = (a.data() as Map)['timestamp'] ?? Timestamp.now();
              Timestamp t2 = (b.data() as Map)['timestamp'] ?? Timestamp.now();
              return t2.compareTo(t1);
            });

            String? storyImage;
            if (docs.isNotEmpty) {
              storyImage = (docs.first.data() as Map)['storyData'];
            }

            return Stack(
              children: [
                Center(
                  child: storyImage != null
                      ? SafeImage(
                          base64String: storyImage,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      : const Text(
                          "No Recent Story",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: LinearProgressIndicator(
                    value: _controller.value,
                    backgroundColor: Colors.grey[800],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
                Positioned(
                  top: 30,
                  left: 15,
                  child: Row(
                    children: [
                      SafeProfilePic(
                        base64String: widget.user['profilePic'],
                        radius: 18,
                        fallbackText: widget.user['username'] ?? "U",
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.user['username'] ?? "User",
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
                  top: 25,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            );
          },
        ),
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
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          var userData = snapshot.data!.data() as Map<String, dynamic>;
          String name = userData['username'] ?? "User";
          String bio = userData['bio'] ?? "";
          List followers = userData['followers'] ?? [];
          bool isFollowing = followers.contains(currentUid);

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        SafeProfilePic(
                          base64String: userData['profilePic'],
                          radius: 40,
                          fallbackText: name,
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatColumn(postCount, "Posts"),
                              _buildStatColumn(followers.length, "Followers"),
                              _buildStatColumn(
                                userData['following']?.length ?? 0,
                                "Following",
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                        Text(bio),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFollowing
                                  ? Colors.grey[300]
                                  : Colors.blue,
                              foregroundColor: isFollowing
                                  ? Colors.black
                                  : Colors.white,
                            ),
                            child: Text(isFollowing ? "Unfollow" : "Follow"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      receiverId: uid,
                                      receiverName: name,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: const Text(
                              "Message",
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 30),
                  Expanded(
                    child: isFollowing || uid == currentUid
                        ? GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 2,
                                  mainAxisSpacing: 2,
                                ),
                            itemCount: postCount,
                            itemBuilder: (context, index) {
                              var post =
                                  postSnapshot.data!.docs[index].data()
                                      as Map<String, dynamic>;
                              return GestureDetector(
                                onTap: () {
                                  if (context.mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PostDetailsScreen(
                                          postId: post['postId'],
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: SafeImage(
                                  base64String: post['postData'],
                                  fit: BoxFit.cover,
                                ),
                              );
                            },
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.lock_outline,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                                Text(
                                  "This account is private",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
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

  Column _buildStatColumn(int num, String label) {
    return Column(
      children: [
        Text(
          num.toString(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
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
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFF56040)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "MyBanjara",
                  style: GoogleFonts.lobster(fontSize: 45, color: Colors.white),
                ),
                const SizedBox(height: 50),
                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Email",
                    hintStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Password",
                    hintStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text("Log In"),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignUpScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    "Don't have an account? Sign Up",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
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
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
    });
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
            "bio": "New to MyBanjara ✨",
            "profilePic": "",
            "followers": [],
            "following": [],
          });
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF56040), Color(0xFFFD1D1D), Color(0xFF833AB4)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Sign Up",
                  style: TextStyle(
                    fontSize: 32,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    hintText: "Username",
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: "Email",
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: "Password",
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text("Create Account"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SafeImage extends StatelessWidget {
  final String? base64String;
  final double? height;
  final double? width;
  final BoxFit fit;

  const SafeImage({
    super.key,
    required this.base64String,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (base64String == null || base64String!.trim().isEmpty) {
      return Container(
        height: height ?? 200,
        width: width ?? double.infinity,
        color: Colors.grey[200],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
              SizedBox(height: 5),
              Text(
                "No Image Data",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    try {
      String cleanString = base64String!.replaceAll(RegExp(r'\s+'), '');
      int padding = cleanString.length % 4;
      if (padding != 0) {
        cleanString += '=' * (4 - padding);
      }

      Uint8List bytes = base64Decode(cleanString);

      return Image.memory(
        bytes,
        height: height,
        width: width,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: height ?? 200,
            width: width ?? double.infinity,
            color: Colors.grey[200],
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: Colors.grey, size: 40),
                  SizedBox(height: 5),
                  Text(
                    "Image Corrupted",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      return Container(
        height: height ?? 200,
        width: width ?? double.infinity,
        color: Colors.red[50],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 40),
              SizedBox(height: 5),
              Text(
                "Format Error",
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
  }
}

class SafeProfilePic extends StatelessWidget {
  final String? base64String;
  final double radius;
  final String fallbackText;

  const SafeProfilePic({
    super.key,
    required this.base64String,
    required this.radius,
    required this.fallbackText,
  });

  @override
  Widget build(BuildContext context) {
    if (base64String == null || base64String!.trim().isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.blueAccent,
        child: Text(
          fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : "?",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    try {
      String cleanString = base64String!.replaceAll(RegExp(r'\s+'), '');
      int padding = cleanString.length % 4;
      if (padding != 0) {
        cleanString += '=' * (4 - padding);
      }
      Uint8List bytes = base64Decode(cleanString);

      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(bytes),
        onBackgroundImageError: (e, s) {},
      );
    } catch (e) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[400],
        child: const Icon(Icons.person, color: Colors.white),
      );
    }
  }
}
