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
    return Scaffold(
      backgroundColor: Colors.black,
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
