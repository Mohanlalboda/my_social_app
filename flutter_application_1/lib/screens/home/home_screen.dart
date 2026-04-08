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
        child: Column(
          // 🌟 Stack తీసేసి నేరుగా Column వాడుతున్నాం
          children: [
            // 1. పైన స్టోరీ బార్
            const StoryBar(),
            Divider(
              height: 1,
              color: isDark ? Colors.grey[900] : Colors.grey[200],
            ),

            // 🌟 2. NEW UPLOAD PROGRESS BAR (స్టోరీస్ కింద, పోస్ట్‌ల పైన వస్తుంది)
            ValueListenableBuilder<bool>(
              valueListenable: UploadManager().isUploading,
              builder: (context, isUploading, child) {
                if (!isUploading) return const SizedBox.shrink();

                return ValueListenableBuilder<double>(
                  valueListenable: UploadManager().uploadProgress,
                  builder: (context, progress, child) {
                    return ValueListenableBuilder<String>(
                      valueListenable: UploadManager().uploadStatus,
                      builder: (context, status, child) {
                        bool isSuccess = status.contains("Success");
                        bool isError = status.contains("Error");
                        String type = UploadManager()
                            .uploadType
                            .value; // Post, Reel, Story etc.
                        int percentage = (progress * 100).toInt();

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 10,
                          ),
                          color: isDark ? Colors.grey[900] : Colors.grey[50],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // చిన్న ఐకాన్
                                  Icon(
                                    isSuccess
                                        ? Icons.check_circle
                                        : (isError
                                              ? Icons.error
                                              : Icons.cloud_upload),
                                    size: 16,
                                    color: isSuccess
                                        ? Colors.green
                                        : (isError
                                              ? Colors.red
                                              : Colors.lightBlue),
                                  ),
                                  const SizedBox(width: 8),
                                  // టెక్స్ట్ (Uploading... 45% లేదా Post Success)
                                  Expanded(
                                    child: Text(
                                      isSuccess || isError
                                          ? status
                                          : "Uploading $type... $percentage%",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isSuccess
                                            ? Colors.green
                                            : (isDark
                                                  ? Colors.white
                                                  : Colors.black87),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // 🌟 లైట్ బ్లూ కలర్ ఫిల్లింగ్ బార్
                              ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: LinearProgressIndicator(
                                  value: isSuccess
                                      ? 1.0
                                      : (progress > 0 ? progress : null),
                                  minHeight: 4,
                                  backgroundColor: isDark
                                      ? Colors.black54
                                      : Colors.grey[300],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isSuccess
                                        ? Colors.green
                                        : (isError
                                              ? Colors.red
                                              : Colors.lightBlue),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),

            // 3. కింద పోస్ట్ ఫీడ్
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
                      onRefresh: _loadInitialData,
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        itemCount: _postsList.length + (_hasMoreData ? 1 : 0),
                        itemBuilder: (context, index) {
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
      ),
    );
  }
}
