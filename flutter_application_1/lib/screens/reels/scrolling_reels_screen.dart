// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/reel_item.dart';

class ScrollingReelsScreen extends StatefulWidget {
  final List<String>? reelIds;
  final int initialIndex;

  const ScrollingReelsScreen({super.key, this.reelIds, this.initialIndex = 0});

  @override
  State<ScrollingReelsScreen> createState() => _ScrollingReelsScreenState();
}

class _ScrollingReelsScreenState extends State<ScrollingReelsScreen> {
  late PageController _pageController;
  final List<DocumentSnapshot> _reels = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;

  @override
  void initState() {
    super.initState();
    // 🌟 THE FIX: యూజర్ క్లిక్ చేసిన రీల్ దగ్గరే ఓపెన్ అవ్వడానికి
    _pageController = PageController(initialPage: widget.initialIndex);
    _fetchReels();
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
  }

  Future<void> _fetchReels() async {
    if (_isLoading || !_hasMore) return;
    if (mounted) setState(() => _isLoading = true);

    try {
      if (widget.reelIds != null && widget.reelIds!.isNotEmpty) {
        // 🌟 1. Specific Reels (ప్రొఫైల్/సెర్చ్ గ్రిడ్ నుండి వచ్చినప్పుడు)
        // Firestore whereIn కేవలం 10 ఐటమ్స్ కే పనిచేస్తుంది, కాబట్టి వాటిని ముక్కలు చేసి లాగుతున్నాం
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

        // పంపిన లిస్ట్ ఆర్డర్ లోనే రీల్స్ ఉండేలా సార్ట్ చేస్తున్నాం
        fetchedDocs.sort(
          (a, b) => widget.reelIds!
              .indexOf(a.id)
              .compareTo(widget.reelIds!.indexOf(b.id)),
        );

        if (mounted) {
          setState(() {
            _reels.addAll(fetchedDocs);
            _hasMore = false; // గ్రిడ్ నుండి వస్తే ఇంకా లాగాల్సిన పని లేదు
          });
        }
      } else {
        // 🌟 2. Global Reels Screen (యాప్ ఓపెన్ చేసినప్పుడు వచ్చే ప్యాజినేషన్)
        Query query = FirebaseFirestore.instance
            .collection('posts')
            .where('isReel', isEqualTo: true)
            .orderBy('timestamp', descending: true)
            .limit(10); // 🌟 10 మాత్రమే లాగుతాం

        if (_lastDoc != null) {
          query = query.startAfterDocument(_lastDoc!);
        }

        var snapshot = await query.get();

        if (snapshot.docs.length < 10) {
          _hasMore = false; // ఇంక లాగడానికి ఏమీ లేవని ఫిక్స్
        }

        if (snapshot.docs.isNotEmpty) {
          _lastDoc = snapshot.docs.last;
          if (mounted) {
            setState(() {
              _reels.addAll(snapshot.docs);
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Reel Fetch Error: $e");
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
                  style: TextStyle(color: Colors.white70),
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
          itemCount:
              _reels.length + (_hasMore ? 1 : 0), // లోడింగ్ కోసం ఎక్స్‌ట్రా 1
          onPageChanged: (i) {
            // చివరికి రాగానే ఆటోమేటిక్ గా నెక్స్ట్ 10 రీల్స్ లాగుతుంది
            if (i >= _reels.length - 2 && _hasMore) {
              _fetchReels();
            }
          },
          itemBuilder: (context, index) {
            if (index == _reels.length) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.red),
              );
            }

            var data = _reels[index].data() as Map<String, dynamic>;
            String reelId = _reels[index].id;

            return ReelItem(key: ValueKey(reelId), reel: data, reelId: reelId);
          },
        ),
      ),
    );
  }
}
