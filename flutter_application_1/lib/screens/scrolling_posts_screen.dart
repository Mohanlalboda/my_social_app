import 'package:flutter/material.dart';
import 'post_details_screen.dart'; // మీ పాత పోస్ట్ చూసే స్క్రీన్

class ScrollingPostsScreen extends StatefulWidget {
  final List<String> postIds;
  final int initialIndex;

  const ScrollingPostsScreen({
    super.key,
    required this.postIds,
    required this.initialIndex,
  });

  @override
  State<ScrollingPostsScreen> createState() => _ScrollingPostsScreenState();
}

class _ScrollingPostsScreenState extends State<ScrollingPostsScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    // 🌟 మీరు ఏ ఫోటోపై క్లిక్ చేశారో, అది ముందుగా ఓపెన్ అయ్యేలా సెట్ చేస్తున్నాం
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
      backgroundColor:
          Colors.black, // ఇన్‌స్టాగ్రామ్ లాగా బ్లాక్ బ్యాక్‌గ్రౌండ్
      body: PageView.builder(
        scrollDirection:
            Axis.vertical, // 🌟 పైకి కిందకి స్క్రోల్ అవ్వడానికి ఇది ముఖ్యం
        controller: _pageController,
        itemCount: widget.postIds.length,
        itemBuilder: (context, index) {
          // 🌟 ఇక్కడ మీ పాత PostDetailsScreen ని పేజీల్లాగా వాడుతున్నాం!
          return PostDetailsScreen(postId: widget.postIds[index]);
        },
      ),
    );
  }
}
