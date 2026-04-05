// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../widgets/reel_item.dart'; // పాత వీడియోల కోసం మీ ఒరిజినల్ ఐటెమ్

class ScrollingReelsScreen extends StatefulWidget {
  final List<String>? reelIds;
  final int initialIndex;

  const ScrollingReelsScreen({super.key, this.reelIds, this.initialIndex = 0});

  @override
  State<ScrollingReelsScreen> createState() => _ScrollingReelsScreenState();
}

class _ScrollingReelsScreenState extends State<ScrollingReelsScreen> {
  final PageController _pageController = PageController();
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  final List<DocumentSnapshot> _reels = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;

  @override
  void initState() {
    super.initState();
    _fetchReels();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialIndex > 0 && _reels.isNotEmpty) {
        _pageController.jumpToPage(widget.initialIndex);
      }
    });
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
    await _fetchReels();
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

  Future<void> _fetchReels() async {
    if (_isLoading || !_hasMore) return;
    if (mounted) setState(() => _isLoading = true);

    try {
      Query query = FirebaseFirestore.instance
          .collection('reels')
          .orderBy('timestamp', descending: true);

      if (widget.reelIds != null && widget.reelIds!.isNotEmpty) {
        query = query.where(FieldPath.documentId, whereIn: widget.reelIds);
      } else {
        query = query.limit(10);
        if (_lastDoc != null) query = query.startAfterDocument(_lastDoc!);
      }

      var snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastDoc = snapshot.docs.last;

        // 🌟 ఇక్కడ కేవలం 'video' టైప్ ఉన్నవాటినే చూపిస్తున్నాం. ఆటో-రీల్స్ రావు!
        var videoReels = snapshot.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return data['type'] != 'auto_reel';
        }).toList();

        if (mounted) setState(() => _reels.addAll(videoReels));
      }
      if (snapshot.docs.length < 10) _hasMore = false;
    } catch (e) {
      debugPrint("Fetch Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_reels.isEmpty && _isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    if (_reels.isEmpty && !_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: RefreshIndicator(
          onRefresh: _refreshReels,
          color: Colors.red,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 300),
              Center(
                child: Text(
                  "No Reels Found. 🎬\nPull down to refresh.",
                  textAlign: TextAlign.center,
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
        color: Colors.red,
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: _reels.length + (_hasMore ? 1 : 0),
          onPageChanged: (i) {
            if (i == _reels.length) _fetchReels();
          },
          itemBuilder: (context, index) {
            if (index == _reels.length) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.red),
              );
            }

            var data = _reels[index].data() as Map<String, dynamic>;
            String reelId = _reels[index].id;
            data['postId'] = reelId;

            // 🌟 కేవలం వీడియో రీల్స్ మాత్రమే వస్తాయి. (పాత ReelItem వాడుతున్నాం)
            return ReelItem(
              key: ValueKey("video_$reelId"),
              reel: data,
              reelId: reelId,
            );
          },
        ),
      ),
    );
  }
}
