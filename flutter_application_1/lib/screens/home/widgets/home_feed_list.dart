// lib/screens/home/widgets/home_feed_list.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'home_post_card.dart';
import 'home_reel_card.dart';
import 'suggested_friends_widget.dart';
import 'suggested_reels_widget.dart';

import '../../../helpers/ad_helper.dart';
import '../../../widgets/my_native_ad_widget.dart';

class UnifiedFeedList extends StatefulWidget {
  final int selectedFeedTab;
  final String myVillageName;
  final int refreshKey;

  const UnifiedFeedList({
    super.key,
    required this.selectedFeedTab,
    required this.myVillageName,
    required this.refreshKey,
  });

  @override
  State<UnifiedFeedList> createState() => _UnifiedFeedListState();
}

class _UnifiedFeedListState extends State<UnifiedFeedList> {
  late StreamController<List<DocumentSnapshot>> _feedController;
  final List<DocumentSnapshot> _allFeedItems = [];
  final String _currentUid = FirebaseAuth.instance.currentUser!.uid;
  final ScrollController _scrollController = ScrollController();

  final Set<int> _shownAdIndices = {};

  bool _isLoadingMore = false;
  bool _hasMorePosts = true;
  bool _hasMoreReels = true;
  bool _isIndexError = false;
  DocumentSnapshot? _lastPostDoc;
  DocumentSnapshot? _lastReelDoc;
  final int _limit = 15;

  @override
  void initState() {
    super.initState();
    _feedController = StreamController<List<DocumentSnapshot>>.broadcast();
    AdHelper.loadInterstitial();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 300) {
        _fetchMoreFeed();
      }
    });

    _fetchInitialFeed();
  }

  @override
  void didUpdateWidget(covariant UnifiedFeedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey ||
        oldWidget.selectedFeedTab != widget.selectedFeedTab ||
        oldWidget.myVillageName != widget.myVillageName) {
      _shownAdIndices.clear();
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      _fetchInitialFeed();
    }
  }

  Future<void> _fetchInitialFeed() async {
    _hasMorePosts = true;
    _hasMoreReels = true;
    _isIndexError = false;
    _lastPostDoc = null;
    _lastReelDoc = null;
    _allFeedItems.clear();

    if (!_feedController.isClosed) _feedController.add([]);

    try {
      Query postsQuery = FirebaseFirestore.instance.collection('posts');
      Query reelsQuery = FirebaseFirestore.instance.collection('reels');

      if (widget.selectedFeedTab == 1 && widget.myVillageName.isNotEmpty) {
        postsQuery = postsQuery
            .where('village', isEqualTo: widget.myVillageName)
            .orderBy('timestamp', descending: true)
            .limit(_limit);
        reelsQuery = reelsQuery
            .where('village', isEqualTo: widget.myVillageName)
            .orderBy('timestamp', descending: true)
            .limit(_limit);
      } else {
        postsQuery = postsQuery
            .orderBy('timestamp', descending: true)
            .limit(_limit);
        reelsQuery = reelsQuery
            .orderBy('timestamp', descending: true)
            .limit(_limit);
      }

      final postsSnap = await postsQuery.get();
      final reelsSnap = await reelsQuery.get();

      if (postsSnap.docs.isNotEmpty)
        _lastPostDoc = postsSnap.docs.last;
      else
        _hasMorePosts = false;
      if (reelsSnap.docs.isNotEmpty)
        _lastReelDoc = reelsSnap.docs.last;
      else
        _hasMoreReels = false;

      _mergeAndAddData(postsSnap.docs, reelsSnap.docs);
    } catch (e) {
      debugPrint("Error fetching feed: $e");
      String errStr = e.toString().toLowerCase();
      if (errStr.contains("failed-precondition") || errStr.contains("index")) {
        if (mounted) setState(() => _isIndexError = true);
      }
    }
  }

  Future<void> _fetchMoreFeed() async {
    if (_isLoadingMore) return;
    if (!_hasMorePosts && !_hasMoreReels) return;

    if (mounted) setState(() => _isLoadingMore = true);

    try {
      Query postsQuery = FirebaseFirestore.instance.collection('posts');
      Query reelsQuery = FirebaseFirestore.instance.collection('reels');

      if (widget.selectedFeedTab == 1 && widget.myVillageName.isNotEmpty) {
        postsQuery = postsQuery
            .where('village', isEqualTo: widget.myVillageName)
            .orderBy('timestamp', descending: true)
            .limit(_limit);
        reelsQuery = reelsQuery
            .where('village', isEqualTo: widget.myVillageName)
            .orderBy('timestamp', descending: true)
            .limit(_limit);
      } else {
        postsQuery = postsQuery
            .orderBy('timestamp', descending: true)
            .limit(_limit);
        reelsQuery = reelsQuery
            .orderBy('timestamp', descending: true)
            .limit(_limit);
      }

      List<DocumentSnapshot> newPosts = [];
      List<DocumentSnapshot> newReels = [];

      if (_hasMorePosts) {
        if (_lastPostDoc != null)
          postsQuery = postsQuery.startAfterDocument(_lastPostDoc!);
        var pSnap = await postsQuery.get();
        newPosts = pSnap.docs;
        if (newPosts.isNotEmpty)
          _lastPostDoc = newPosts.last;
        else
          _hasMorePosts = false;
      }
      if (_hasMoreReels) {
        if (_lastReelDoc != null)
          reelsQuery = reelsQuery.startAfterDocument(_lastReelDoc!);
        var rSnap = await reelsQuery.get();
        newReels = rSnap.docs;
        if (newReels.isNotEmpty)
          _lastReelDoc = newReels.last;
        else
          _hasMoreReels = false;
      }
      _mergeAndAddData(newPosts, newReels);
    } catch (e) {
      debugPrint("Error fetching more feed: $e");
    }

    if (mounted) setState(() => _isLoadingMore = false);
  }

  void _mergeAndAddData(
    List<DocumentSnapshot> newPosts,
    List<DocumentSnapshot> newReels,
  ) {
    List<DocumentSnapshot> combined = [...newPosts, ...newReels];
    _allFeedItems.addAll(combined);

    _allFeedItems.sort((a, b) {
      var aData = a.data() as Map<String, dynamic>? ?? {};
      var bData = b.data() as Map<String, dynamic>? ?? {};

      List aSeenBy = aData['viewedBy'] ?? aData['seenBy'] ?? [];
      List bSeenBy = bData['viewedBy'] ?? bData['seenBy'] ?? [];

      bool aSeen = aSeenBy.contains(_currentUid);
      bool bSeen = bSeenBy.contains(_currentUid);

      if (!aSeen && bSeen) return -1;
      if (aSeen && !bSeen) return 1;

      var aTime = aData['timestamp'] ?? aData['datePublished'];
      var bTime = bData['timestamp'] ?? bData['datePublished'];

      DateTime dtA = (aTime is Timestamp)
          ? aTime.toDate()
          : (DateTime.tryParse(aTime.toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0));
      DateTime dtB = (bTime is Timestamp)
          ? bTime.toDate()
          : (DateTime.tryParse(bTime.toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0));

      return dtB.compareTo(dtA);
    });

    final ids = <String>{};
    _allFeedItems.retainWhere((x) => ids.add(x.id));

    if (!_feedController.isClosed) _feedController.add(_allFeedItems);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _feedController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isIndexError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 60,
              ),
              const SizedBox(height: 15),
              const Text(
                "Firebase Index Required! ⚠️",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 10),
              Text(
                "విలేజ్ పోస్టులు ఫిల్టర్ అవ్వడానికి Firebase లో Index అవసరం.\n\nదయచేసి మీ VS Code Terminal (Debug Console) ఓపెన్ చేయండి. అక్కడ బ్లూ కలర్ లో ఒక లింక్ వచ్చి ఉంటుంది. ఆ లింక్ ని క్లిక్ చేస్తే ఆటోమేటిక్ గా క్రియేట్ అయిపోతుంది!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchInitialFeed,
                icon: const Icon(Icons.refresh),
                label: const Text("Refresh Now"),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _feedController.stream,
      builder: (context, snapshot) {
        if (widget.selectedFeedTab == 1 && widget.myVillageName.isEmpty) {
          return const Center(
            child: Text(
              "Please update your Tanda/Village name\nin your Profile first! 🏕️",
              textAlign: TextAlign.center,
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            _allFeedItems.isEmpty)
          return const Center(
            child: CircularProgressIndicator(color: Colors.blueAccent),
          );
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return const Center(child: Text('No feeds yet. 🌟'));

        var feedItems = snapshot.data!;

        return RefreshIndicator(
          onRefresh: _fetchInitialFeed,
          color: Colors.blueAccent,
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          strokeWidth: 3,
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: feedItems.length,
            itemBuilder: (context, index) {
              var doc = feedItems[index];
              var data = doc.data() as Map<String, dynamic>;

              bool isReelItem =
                  data['isReel'] == true ||
                  data['type'] == 'video' ||
                  data['type'] == 'reel' ||
                  data.containsKey('videoUrl');

              WidgetsBinding.instance.addPostFrameCallback((_) {
                List viewedBy = data['viewedBy'] ?? data['seenBy'] ?? [];
                if (!viewedBy.contains(_currentUid)) {
                  FirebaseFirestore.instance
                      .collection(isReelItem ? 'reels' : 'posts')
                      .doc(doc.id)
                      .update({
                        'viewedBy': FieldValue.arrayUnion([_currentUid]),
                      })
                      .catchError((e) => debugPrint("Error: $e"));
                }
              });

              Widget feedContentWidget;
              if (isReelItem) {
                feedContentWidget = Container(
                  height: 550,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: HomeReelCard(reelData: data, reelId: doc.id),
                );
              } else {
                feedContentWidget = HomePostCard(
                  postData: data,
                  postId: doc.id,
                );
              }

              // 1. ప్రతి 12వ ఐటమ్ కి ఇంటర్స్‌టీషియల్ యాడ్ ట్రిగ్గర్ అవుతుంది
              if (index > 0 &&
                  index % 12 == 0 &&
                  !_shownAdIndices.contains(index)) {
                _shownAdIndices.add(index);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  AdHelper.showInterstitial();
                });
              }

              // 🌟 డైనమిక్ లిస్ట్ క్రియేట్ చేస్తున్నాం బాస్ (ఓవర్‌ల్యాప్ అవ్వకుండా ఉండటానికి)
              List<Widget> columnChildren = [feedContentWidget];

              // 🌟 THE FIX: ప్రతి 12వ ఇండెక్స్ (ఇంటర్స్‌టీషియల్ యాడ్ వచ్చే చోట) ఆల్టర్నేటివ్‌గా బాక్స్‌లు యాడ్ అవుతాయి!
              if (index > 0 && index % 12 == 0) {
                int adCount =
                    index ~/
                    12; // ఇది ఎన్నోవ యాడో లెక్కిస్తుంది (1, 2, 3, 4...)

                if (adCount % 2 != 0) {
                  // 1వ సారి, 3వ సారి, 5వ సారి... -> Suggested Friends వస్తుంది
                  columnChildren.add(SuggestedFriendsWidget(isDark: isDark));
                } else {
                  // 2వ సారి, 4వ సారి, 6వ సారి... -> Suggested Reels వస్తుంది
                  columnChildren.add(SuggestedReelsWidget(isDark: isDark));
                }
              }

              // 2. ప్రతి 5వ పోస్ట్ కి కింద నేటివ్ యాడ్ వస్తుంది
              if (index > 0 && index % 5 == 0) {
                columnChildren.add(const MyNativeAdWidget());
              }

              // 3. అన్‌లిమిటెడ్ స్క్రోలింగ్ లోడర్
              if (index == feedItems.length - 1 && _isLoadingMore) {
                columnChildren.add(
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  ),
                );
              }

              return Column(children: columnChildren);
            },
          ),
        );
      },
    );
  }
}
