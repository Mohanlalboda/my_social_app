import 'package:flutter/material.dart';
import 'post_details_screen.dart';

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
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 ఫోన్ డార్క్ మోడ్ థీమ్ వాల్యూ ఇక్కడ తెచ్చుకుంటున్నాం
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // 🌟 డార్క్ మోడ్ అయితే బ్లాక్, లైట్ మోడ్ అయితే వైట్
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _pageController,
        itemCount: widget.postIds.length,
        itemBuilder: (context, index) {
          return PostDetailsScreen(postId: widget.postIds[index]);
        },
      ),
    );
  }
}
