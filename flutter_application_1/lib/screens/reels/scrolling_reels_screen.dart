// ignore_for_file: curly_braces_in_flow_control_structures, empty_catches
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // 🌟 THE FIX: యాడ్స్ ప్యాకేజీ ఇంపోర్ట్ చేసాం
import '../../widgets/reel_item.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});
  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  @override
  Widget build(BuildContext context) {
    return const ScrollingReelsScreen();
  }
}

class ScrollingReelsScreen extends StatefulWidget {
  final List<String>? reelIds;
  final int initialIndex;

  const ScrollingReelsScreen({super.key, this.reelIds, this.initialIndex = 0});

  @override
  State<ScrollingReelsScreen> createState() => _ScrollingReelsScreenState();
}

class _ScrollingReelsScreenState extends State<ScrollingReelsScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  late PageController _pageController;

  final List<DocumentSnapshot> _reels = [];
  List<dynamic> _followingList = [];
  DocumentSnapshot? _lastDoc;

  bool _isLoading = false;
  bool _hasMore = true;

  // 🌟 యాడ్స్ మరియు ఆడియో కంట్రోల్ వేరియబుల్స్
  int _swipeCount = 0;
  int _currentPageIndex = 0; // ఏ రీల్ ప్లే అవుతుందో తెలుసుకోవడానికి
  InterstitialAd? _interstitialAd;
  bool _isAdShowing = false; // యాడ్ ప్లే అవుతున్నప్పుడు రీల్ పాజ్ చేయడానికి

  @override
  void initState() {
    super.initState();
    _currentPageIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _loadInitialData();
    _loadAd(); // 🌟 స్క్రీన్ ఓపెన్ అవ్వగానే బ్యాక్ గ్రౌండ్ లో యాడ్ రెడీ చేస్తాం
  }

  @override
  void dispose() {
    _pageController.dispose();
    _interstitialAd?.dispose(); // 🌟 మెమరీ లీక్ అవ్వకుండా డిస్పోజ్
    super.dispose();
  }

  // 🌟 యాడ్ ని ముందుగానే లోడ్ చేసి ఉంచే ఫంక్షన్
  void _loadAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712', // Google Test ID
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (error) => _interstitialAd = null,
      ),
    );
  }

  // 🌟 యాడ్ ని ప్లే చేసే ఫంక్షన్ & ఆడియో కంట్రోల్
  void _showAd() {
    if (_interstitialAd == null) {
      _loadAd();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        // 🌟 యాడ్ ప్లే అవ్వగానే రీల్ ఆడియో పాజ్ అవుతుంది
        if (mounted) setState(() => _isAdShowing = true);
      },
      onAdDismissedFullScreenContent: (ad) {
        // 🌟 యాడ్ క్లోజ్ అవ్వగానే మళ్ళీ రీల్ ఆడియో ఆన్ అవుతుంది
        if (mounted) setState(() => _isAdShowing = false);
        ad.dispose();
        _loadAd(); // నెక్స్ట్ యాడ్ కి రెడీ చేస్తాం
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        if (mounted) setState(() => _isAdShowing = false);
        ad.dispose();
        _loadAd();
      },
    );

    _interstitialAd!.show();
    _interstitialAd = null;
  }

  Future<void> _refreshReels() async {
    if (_isLoading) return;
    setState(() {
      _reels.clear();
      _lastDoc = null;
      _hasMore = true;
      _swipeCount = 0;
    });
    await _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      _followingList = userDoc.data()?['following'] ?? [];

      await _fetchReels();
    } catch (e) {
      debugPrint("Error loading data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchReels() async {
    if (!_hasMore) return;

    if (widget.reelIds != null && widget.reelIds!.isNotEmpty) {
      try {
        List<DocumentSnapshot> fetchedDocs = [];
        for (var i = 0; i < widget.reelIds!.length; i += 10) {
          var chunk = widget.reelIds!.sublist(
            i,
            (i + 10 > widget.reelIds!.length) ? widget.reelIds!.length : i + 10,
          );
          var snap = await FirebaseFirestore.instance
              .collection('posts')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          fetchedDocs.addAll(snap.docs);
        }
        fetchedDocs.sort(
          (a, b) => widget.reelIds!
              .indexOf(a.id)
              .compareTo(widget.reelIds!.indexOf(b.id)),
        );
        if (mounted) {
          setState(() {
            _reels.addAll(fetchedDocs);
            _hasMore = false;
          });
        }
      } catch (e) {
        debugPrint("Error fetching specific reels: $e");
      }
      return;
    }

    if (mounted) setState(() => _isLoading = true);
    try {
      Query query = FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(60);

      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      var snapshot = await query.get();

      if (snapshot.docs.length < 60) {
        _hasMore = false;
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDoc = snapshot.docs.last;

        List<DocumentSnapshot> newlyFetchedValidReels = [];

        for (var doc in snapshot.docs) {
          var data = doc.data() as Map<String, dynamic>;
          String type = data['type'] ?? 'image';

          if (type != 'video') continue;

          bool isPublic = data['isPublic'] ?? true;
          String ownerId = data['ownerId'] ?? "";
          if (!isPublic &&
              ownerId != currentUid &&
              !_followingList.contains(ownerId))
            continue;

          if (!_reels.any((r) => r.id == doc.id)) {
            newlyFetchedValidReels.add(doc);
          }
        }

        _sortAndAppendNewReels(newlyFetchedValidReels);
      }
    } catch (e) {
      debugPrint("Reel Fetch Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sortAndAppendNewReels(List<DocumentSnapshot> newReelsChunk) {
    List<DocumentSnapshot> bucketFollowingUnseen = [];
    List<DocumentSnapshot> bucketNewRandom = [];
    List<DocumentSnapshot> bucketSeenJumbled = [];

    for (var doc in newReelsChunk) {
      var data = doc.data() as Map<String, dynamic>;

      String ownerId = data['ownerId'] ?? "";
      bool isFollowing =
          _followingList.contains(ownerId) || ownerId == currentUid;
      List viewedBy = data['viewedBy'] is List ? data['viewedBy'] : [];
      bool isSeen = viewedBy.contains(currentUid);

      if (isSeen) {
        bucketSeenJumbled.add(doc);
      } else if (isFollowing) {
        bucketFollowingUnseen.add(doc);
      } else {
        bucketNewRandom.add(doc);
      }
    }

    final random = Random();
    bucketNewRandom.shuffle(random);
    bucketSeenJumbled.shuffle(random);

    setState(() {
      _reels.addAll([
        ...bucketFollowingUnseen,
        ...bucketNewRandom,
        ...bucketSeenJumbled,
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_reels.isEmpty && _isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
        ),
      );
    }

    if (_reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: RefreshIndicator(
          onRefresh: _refreshReels,
          child: ListView(
            children: const [
              SizedBox(height: 300),
              Center(
                child: Text(
                  "No Reels Found 🎬",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        onRefresh: _refreshReels,
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(),
          itemCount: _reels.length + 1,
          onPageChanged: (i) {
            setState(
              () => _currentPageIndex = i,
            ); // 🌟 ఏ రీల్ దగ్గర ఉన్నామో అప్డేట్ చేస్తాం

            // 🌟 ప్రతి 5 రీల్స్ చూసిన తర్వాత యాడ్ వస్తుంది
            _swipeCount++;
            if (_swipeCount > 0 && _swipeCount % 5 == 0) {
              _showAd();
            }

            if (i >= _reels.length - 2 && _hasMore && !_isLoading) {
              _fetchReels();
            }
          },
          itemBuilder: (context, index) {
            if (index == _reels.length) {
              return Container(
                color: Colors.black,
                child: Center(
                  child: _hasMore
                      ? const CircularProgressIndicator(
                          color: Color(0xFF00E5FF),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.white54,
                              size: 50,
                            ),
                            SizedBox(height: 10),
                            Text(
                              "You've seen all reels! 🚀",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                ),
              );
            }

            var data = _reels[index].data() as Map<String, dynamic>;
            String reelId = _reels[index].id;

            // 🌟 THE MAIN AUDIO FIX: యాడ్ వస్తున్నప్పుడు ఈ వాల్యూ false అవుతుంది, రీల్ పాజ్ అవుతుంది.
            bool isCurrentlyPlaying =
                (index == _currentPageIndex) && !_isAdShowing;

            return ReelItem(
              key: ValueKey(reelId),
              reel: data,
              reelId: reelId,
              isCurrentPage: isCurrentlyPlaying, // 🌟 ఇక్కడ పాస్ చేశాం
            );
          },
        ),
      ),
    );
  }
}

class SingleReelScreen extends StatelessWidget {
  final String reelId;
  const SingleReelScreen({super.key, required this.reelId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('posts')
            .doc(reelId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          if (!snapshot.data!.exists)
            return const Center(
              child: Text(
                "Reel not found",
                style: TextStyle(color: Colors.white),
              ),
            );
          return ScrollingReelsScreen(reelIds: [reelId]);
        },
      ),
    );
  }
}
