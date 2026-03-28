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
  late int _currentIndex; // 🌟 కరెంట్ ఇండెక్స్ ట్రాక్ చేయడానికి

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
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
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.reelIds.length,
        onPageChanged: (index) {
          // 🌟 పేజీ మారినప్పుడు ఇండెక్స్ అప్‌డేట్ చేస్తున్నాం
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return FutureBuilder<DocumentSnapshot>(
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
              reelData['postId'] = widget.reelIds[index];

              return ReelItem(
                reel: reelData,
                reelId: widget.reelIds[index],
                isCurrentPage: _currentIndex == index, // 🌟 మ్యాజిక్ ఇక్కడే!
              );
            },
          );
        },
      ),
    );
  }
}
