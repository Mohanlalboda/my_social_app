// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/reel_item.dart';

class ScrollingReelsScreen extends StatefulWidget {
  final List<String> reelIds;
  final int initialIndex;

  const ScrollingReelsScreen({
    super.key,
    required this.reelIds,
    required this.initialIndex,
  });

  @override
  State<ScrollingReelsScreen> createState() => _ScrollingReelsScreenState();
}

class _ScrollingReelsScreenState extends State<ScrollingReelsScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    // 🌟 ఏ రీల్ మీద క్లిక్ చేశారో, కరెక్ట్ గా అక్కడి నుండే ఓపెన్ అవుతుంది
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // 🌟 పైకి కిందకి స్క్రోల్ చేయడానికి PageView
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.reelIds.length,
        itemBuilder: (context, index) {
          return FutureBuilder<DocumentSnapshot>(
            // 🌟 మ్యాజిక్ ఇక్కడే జరిగింది: 'reels' బదులు 'posts' వాడాం!
            future: FirebaseFirestore.instance
                .collection('posts')
                .doc(widget.reelIds[index])
                .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              if (!snapshot.data!.exists)
                return const Center(
                  child: Text(
                    "Reel deleted",
                    style: TextStyle(color: Colors.white),
                  ),
                );

              var reelData = snapshot.data!.data() as Map<String, dynamic>;
              // 🌟 సేఫ్టీ కోసం postId ని డేటాలోకి పంపుతున్నాం
              reelData['postId'] = widget.reelIds[index];

              return ReelItem(reel: reelData, reelId: widget.reelIds[index]);
            },
          );
        },
      ),
    );
  }
}
