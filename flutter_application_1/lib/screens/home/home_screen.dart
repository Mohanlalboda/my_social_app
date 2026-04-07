// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../widgets/story_bar.dart';
import '../../widgets/post_widget.dart';
import '../../services/upload_manager.dart';
import '../../widgets/suggested_friends.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  // 🌟 PAGINATION VARIABLES 🌟
  final ScrollController _scrollController = ScrollController();
  final List<DocumentSnapshot> _postsList = [];
  List<dynamic> _followingList = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMoreData = true;
  bool _isInitialLoading = true; // ఫస్ట్ టైమ్ లోడింగ్ కోసం

  @override
  void initState() {
    super.initState();
    _loadInitialData(); // యాప్ ఓపెన్ అవ్వగానే డేటా లాగడం

    // 🌟 యూజర్ కిందకి స్క్రోల్ చేస్తున్నాడో లేదో కనిపెట్టే లాజిక్
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _fetchMorePosts(); // కిందకి రాగానే ఇంకో 10 పోస్ట్‌లు లాగుతాం
      }
    });
  }

  // 🌟 మొదటి 10 పోస్ట్‌లు లాగే ఫంక్షన్
  Future<void> _loadInitialData() async {
    setState(() => _isInitialLoading = true);

    try {
      // 1. మన Following లిస్ట్ లాగుతున్నాం
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      _followingList = userDoc.data()?['following'] ?? [];

      _lastDocument = null;
      _postsList.clear();
      _hasMoreData = true;

      // 2. మొదటి 10 పోస్ట్‌లు
      await _fetchMorePosts();
    } catch (e) {
      debugPrint("Error loading initial data: $e");
    } finally {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  // 🌟 మిగతా 10 పోస్ట్‌లు లాగే ఫంక్షన్ (Pagination Logic)
  Future<void> _fetchMorePosts() async {
    if (_isLoading || !_hasMoreData) return;
    setState(() => _isLoading = true);

    try {
      // 🌟 మ్యాజిక్ ఇక్కడే: ఒకేసారి అన్నీ లాగకుండా limit(10) పెట్టాం!
      Query q = FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(10);

      // పాత డాక్యుమెంట్ ఎక్కడ ఆగిపోయిందో, అక్కడి నుండి స్టార్ట్ చేయాలి
      if (_lastDocument != null) {
        q = q.startAfterDocument(_lastDocument!);
      }

      var snapshot = await q.get();

      if (snapshot.docs.length < 10) {
        _hasMoreData = false; // ఇంక లాగడానికి పోస్ట్‌లు లేవు అని ఫిక్స్
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last; // లాస్ట్ డాక్యుమెంట్ ని సేవ్ చేసాం

        // 🌟 వచ్చిన 10 పోస్ట్‌లలో పనికొచ్చేవి (Images & Public/Following) ఫిల్టర్ చేస్తున్నాం
        var validPosts = snapshot.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          bool isPublic = data['isPublic'] ?? true;
          bool isNotReel = data['type'] != 'video';
          String ownerId = data['ownerId'] ?? "";

          return (isPublic ||
                  _followingList.contains(ownerId) ||
                  ownerId == currentUid) &&
              isNotReel;
        }).toList();

        _postsList.addAll(validPosts);
      }
    } catch (e) {
      debugPrint("Error fetching more posts: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // ---------------- 1. MAIN HOME SCREEN ----------------
            Column(
              children: [
                const StoryBar(),
                Divider(
                  height: 1,
                  color: isDark ? Colors.grey[900] : Colors.grey[200],
                ),
                Expanded(
                  child: _isInitialLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF00E5FF),
                          ),
                        )
                      : _postsList.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.photo_camera_outlined,
                                size: 60,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 15),
                              Text(
                                "No posts yet. Follow people!",
                                style: TextStyle(color: Colors.grey),
                              ),
                              SizedBox(height: 30),
                              SuggestedFriendsWidget(), // సజెస్టెడ్ ఫ్రెండ్స్
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: const Color(0xFF00E5FF),
                          onRefresh:
                              _loadInitialData, // 🌟 స్వైప్ చేస్తే రీఫ్రెష్
                          child: ListView.builder(
                            controller:
                                _scrollController, // 🌟 స్క్రోల్ కంట్రోలర్ ఇక్కడ కనెక్ట్ చేసాం
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            itemCount:
                                _postsList.length + (_hasMoreData ? 1 : 0),
                            itemBuilder: (context, index) {
                              // 🌟 కిందకి రాగానే లోడింగ్ ఐకాన్ చూపించడం
                              if (index == _postsList.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              }

                              var postDoc = _postsList[index];
                              var post = postDoc.data() as Map<String, dynamic>;
                              post['postId'] = postDoc.id;

                              return PostWidget(post: post);
                            },
                          ),
                        ),
                ),
              ],
            ),

            // ---------------- 2. GLOBAL UPLOAD PROGRESS BAR ----------------
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: ValueListenableBuilder<bool>(
                valueListenable: UploadManager().isUploading,
                builder: (context, isUploading, child) {
                  if (!isUploading) return const SizedBox.shrink();

                  return Material(
                    elevation: 10,
                    borderRadius: BorderRadius.circular(15),
                    color: isDark ? Colors.grey[900] : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ValueListenableBuilder<String>(
                            valueListenable: UploadManager().uploadStatus,
                            builder: (context, status, child) {
                              bool isSuccess =
                                  status.contains("Success") ||
                                  status.contains("Ready");
                              return Row(
                                children: [
                                  Icon(
                                    isSuccess
                                        ? Icons.check_circle
                                        : Icons.cloud_upload_outlined,
                                    color: isSuccess
                                        ? Colors.green
                                        : const Color(0xFFFD1D1D),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          ValueListenableBuilder<double>(
                            valueListenable: UploadManager().uploadProgress,
                            builder: (context, progress, child) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: progress > 0 ? progress : null,
                                  backgroundColor: isDark
                                      ? Colors.grey[800]
                                      : Colors.grey[300],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    progress >= 1.0
                                        ? Colors.green
                                        : const Color(0xFFFD1D1D),
                                  ),
                                  minHeight: 6,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
