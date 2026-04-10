// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'dart:math'; // 🌟 THE FIX: రాండమ్ గా జంబుల్ చేయడానికి ఇది కావాలి
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../widgets/story_bar.dart';
import '../../widgets/post_widget.dart';
import '../../services/upload_manager.dart';
// 🌟 THE FIX: మన నేటివ్ యాడ్ విడ్జెట్ ని ఇంపోర్ట్ చేసుకుంటున్నాం
import '../../widgets/my_native_ad_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  final ScrollController _scrollController = ScrollController();
  final List<DocumentSnapshot> _postsList = [];
  List<dynamic> _followingList = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMoreData = true;
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _fetchMorePosts();
      }
    });
  }

  Future<void> _loadInitialData() async {
    setState(() => _isInitialLoading = true);

    try {
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      _followingList = userDoc.data()?['following'] ?? [];

      _lastDocument = null;
      _postsList.clear();
      _hasMoreData = true;

      await _fetchMorePosts();
    } catch (e) {
      debugPrint("Error loading initial data: $e");
    } finally {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _fetchMorePosts() async {
    if (_isLoading || !_hasMoreData) return;
    setState(() => _isLoading = true);

    try {
      // 🌟 ఒకేసారి 100 లాగుతున్నాం, అప్పుడే మన బకెట్ అల్గారిథమ్ పక్కాగా పనిచేస్తుంది
      Query q = FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(100);

      if (_lastDocument != null) {
        q = q.startAfterDocument(_lastDocument!);
      }

      var snapshot = await q.get();

      if (snapshot.docs.length < 100) {
        _hasMoreData = false;
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;

        List<DocumentSnapshot> bucketFollowingUnseen = [];
        List<DocumentSnapshot> bucketNewRandom = [];
        List<DocumentSnapshot> bucketSeenJumbled = [];

        for (var doc in snapshot.docs) {
          var data = doc.data() as Map<String, dynamic>;

          bool isPublic = data['isPublic'] ?? true;
          bool isNotReel = data['type'] != 'video';
          String ownerId = data['ownerId'] ?? "";

          // రీల్స్ మరియు ప్రైవేట్ పోస్ట్స్ (మనం ఫాలో అవ్వనివి) తీసేస్తున్నాం
          if (!isNotReel ||
              (!isPublic &&
                  ownerId != currentUid &&
                  !_followingList.contains(ownerId))) {
            continue;
          }

          bool isFollowing =
              _followingList.contains(ownerId) || ownerId == currentUid;
          List viewedBy = data['viewedBy'] is List ? data['viewedBy'] : [];
          bool isSeen = viewedBy.contains(currentUid);

          // 🌟 BUCKET LOGIC: ఏది ఎందులో పడాలో డిసైడ్ చేస్తున్నాం
          if (isSeen) {
            bucketSeenJumbled.add(doc); // చూసేసినవన్నీ బకెట్ 3 లోకి
          } else {
            if (isFollowing) {
              bucketFollowingUnseen.add(doc); // ఫాలో అవుతూ చూడనివి బకెట్ 1 లోకి
            } else {
              bucketNewRandom.add(doc); // వేరే వాళ్ళ కొత్తవి బకెట్ 2 లోకి
            }
          }
        }

        // 🌟 SHUFFLING (జంబుల్ చేయడం)
        final random = Random();
        bucketNewRandom.shuffle(random); // కొత్తవి రాండమ్ గా వస్తాయి
        bucketSeenJumbled.shuffle(random); // చూసేసినవి మొత్తం జంబుల్ అయిపోతాయి

        // మూడింటిని ఒకే లైన్ లో కలుపుతున్నాం (First: Following, Next: New Random, Last: Seen Jumbled)
        List<DocumentSnapshot> finalSortedPosts = [
          ...bucketFollowingUnseen,
          ...bucketNewRandom,
          ...bucketSeenJumbled,
        ];

        _postsList.addAll(finalSortedPosts);
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
          children: [
            const StoryBar(),
            Divider(
              height: 1,
              color: isDark ? Colors.grey[900] : Colors.grey[200],
            ),

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
                        String type = UploadManager().uploadType.value;
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
                            Icons.check_circle_outline,
                            size: 60,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 15),
                          Text(
                            "You're all caught up! 🚀",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                        // 🌟 THE FIX: యాడ్స్ కౌంట్ ని కూడా కలుపుతున్నాం
                        itemCount:
                            _postsList.length + (_postsList.length ~/ 5) + 1,
                        itemBuilder: (context, index) {
                          // 1. అన్నీ అయిపోయాక లాస్ట్ లో లోడింగ్ స్పిన్నర్
                          if (index ==
                              _postsList.length + (_postsList.length ~/ 5)) {
                            return Padding(
                              padding: const EdgeInsets.all(30.0),
                              child: Center(
                                child: _hasMoreData
                                    ? const CircularProgressIndicator(
                                        strokeWidth: 2,
                                      )
                                    : const Text(
                                        "You're all caught up! 🚀",
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            );
                          }

                          // 2. 🌟 THE FIX: ప్రతి 5 పోస్ట్‌లకి ఒకసారి నేటివ్ యాడ్ విడ్జెట్ ని కాల్ చేస్తున్నాం
                          if (index > 0 && index % 6 == 5) {
                            return const MyNativeAdWidget();
                          }

                          // 3. మిగిలిన ఇండెక్స్‌లలో యాడ్స్ స్కిప్ చేసి కరెక్ట్ పోస్ట్ ఇండెక్స్ తీసుకుంటున్నాం
                          int postIndex = index - (index ~/ 6);

                          var postDoc = _postsList[postIndex];
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
