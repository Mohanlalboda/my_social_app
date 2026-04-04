// ignore_for_file: curly_braces_in_flow_control_structures

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
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  late PageController _pageController;
  List<DocumentSnapshot> _sortedReels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fetchAndSortReels();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 🌟 Unseen First Logic
  Future<void> _fetchAndSortReels() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('type', isEqualTo: 'video')
          .orderBy('timestamp', descending: true)
          .get();

      List<DocumentSnapshot> unseen = [];
      List<DocumentSnapshot> seen = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data();
        List viewers = data['viewers'] ?? [];

        if (viewers.contains(currentUid)) {
          seen.add(doc);
        } else {
          unseen.add(doc);
        }
      }

      if (mounted) {
        setState(() {
          _sortedReels = [...unseen, ...seen];
          _isLoading = false;
        });

        if (_sortedReels.isNotEmpty) {
          _markAsSeen(0);
        }
      }
    } catch (e) {
      debugPrint("Error fetching reels: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _markAsSeen(int index) {
    if (index < 0 || index >= _sortedReels.length) return;

    String reelId = _sortedReels[index].id;
    FirebaseFirestore.instance
        .collection('posts')
        .doc(reelId)
        .update({
          'viewers': FieldValue.arrayUnion([currentUid]),
        })
        .catchError((e) => debugPrint("Seen Update Error: $e"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      // 🌟 పైన టైటిల్ ని కొంచెం స్టైలిష్ గా మార్చాను
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "Reels",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 26,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : RefreshIndicator(
              onRefresh: _fetchAndSortReels,
              color: Colors.black,
              backgroundColor: Colors.white,
              child: _sortedReels.isEmpty
                  ? const Center(
                      child: Text(
                        "No Reels Found. 🎬\nPull down to refresh.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    )
                  : PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      itemCount: _sortedReels.length,
                      onPageChanged: (index) {
                        _markAsSeen(index);
                      },
                      itemBuilder: (context, index) {
                        var reelData =
                            _sortedReels[index].data() as Map<String, dynamic>;
                        String reelId = _sortedReels[index].id;

                        reelData['postId'] = reelId;

                        // 🌟 మ్యాజిక్: ప్రొఫైల్ లో వాడిన అదే 'ReelItem' ని ఇక్కడ వాడుతున్నాం.
                        // ఇందులో ఆల్రెడీ ఆడియో, ఫాలో, లైక్ బటన్స్ అన్నీ పర్ఫెక్ట్ గా ఉన్నాయి!
                        return ReelItem(
                          key: ValueKey(reelId),
                          reel: reelData,
                          reelId: reelId,
                        );
                      },
                    ),
            ),
    );
  }
}
