// ignore_for_file: curly_braces_in_flow_control_structures, empty_catches
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // 🌟 THE FIX: కేవలం ఒకటే ఫైనల్ లిస్ట్ మెయింటైన్ చేస్తాం
  final List<DocumentSnapshot> _reels = [];

  List<dynamic> _followingList = [];
  DocumentSnapshot? _lastDoc;

  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _loadInitialData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _refreshReels() async {
    if (_isLoading) return;
    setState(() {
      _reels.clear();
      _lastDoc = null;
      _hasMore = true;
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

    // 🌟 1. Specific Reels (ప్రొఫైల్/సెర్చ్ గ్రిడ్ నుండి వచ్చినప్పుడు)
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

    // 🌟 2. Global Reels (అల్గారిథమ్ వాడేది ఇక్కడే)
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

          if (type != 'video' && type != 'auto_reel') continue;

          bool isPublic = data['isPublic'] ?? true;
          String ownerId = data['ownerId'] ?? "";
          if (!isPublic &&
              ownerId != currentUid &&
              !_followingList.contains(ownerId))
            continue;

          // డూప్లికేట్స్ రాకుండా చెక్
          if (!_reels.any((r) => r.id == doc.id)) {
            newlyFetchedValidReels.add(doc);
          }
        }

        // 🌟 వచ్చిన కొత్త రీల్స్ ని మాత్రమే అల్గారిథమ్ కి పంపుతున్నాం
        _sortAndAppendNewReels(newlyFetchedValidReels);
      }
    } catch (e) {
      debugPrint("Reel Fetch Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🌟🌟 NEW CHUNK BUCKET ALGORITHM 🌟🌟
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
      // 🌟 THE FIX: పాత రీల్స్ (_reels) ని అలాగే ఉంచి, కొత్త వాటిని సార్ట్ చేసి కింద కలుపుతున్నాం!
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

            return ReelItem(
              key: ValueKey(reelId),
              reel: data,
              reelId: reelId,
              isCurrentPage: true,
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
