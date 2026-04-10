import 'package:flutter/material.dart';
import 'post_details_screen.dart';

// 🌟 THE FIX: నేటివ్ యాడ్ విడ్జెట్ ని ఇంపోర్ట్ చేసుకుంటున్నాం
import '../../widgets/my_native_ad_widget.dart';

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
  int _mappedInitialIndex = 0;

  @override
  void initState() {
    super.initState();

    // 🌟 MATH LOGIC: గ్రిడ్ లో నొక్కిన ఇండెక్స్ కి, మధ్యలో వచ్చే యాడ్స్ కౌంట్ ని కలుపుతున్నాం.
    // అప్పుడే మీరు నొక్కిన పోస్ట్ పక్కాగా అదే ప్లేస్ లో ఓపెన్ అవుతుంది.
    _mappedInitialIndex = widget.initialIndex + (widget.initialIndex ~/ 5);

    _pageController = PageController(initialPage: _mappedInitialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    // 🌟 మొత్తం పోస్ట్‌లు + వాటి మధ్యలో వచ్చే యాడ్స్ కౌంట్
    int totalItems = widget.postIds.length + (widget.postIds.length ~/ 5);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        physics: const BouncingScrollPhysics(), // స్మూత్ స్క్రోలింగ్ కోసం
        controller: _pageController,
        itemCount: totalItems,
        itemBuilder: (context, index) {
          // 🌟 THE FIX: ప్రతి 5 పోస్ట్‌లకి ఒకసారి నేటివ్ యాడ్ పేజీ వస్తుంది (index 5, 11, 17...)
          if (index > 0 && index % 6 == 5) {
            return Scaffold(
              backgroundColor: isDark ? Colors.black : Colors.white,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              body: const Center(
                // 🚀 ఇక్కడ మన యాడ్ వస్తుంది
                child: MyNativeAdWidget(),
              ),
            );
          }

          // 🌟 యాడ్స్ స్కిప్ చేసి ఒరిజినల్ పోస్ట్ ఇండెక్స్ తెచ్చుకోవడం
          int postIndex = index - (index ~/ 6);

          return PostDetailsScreen(postId: widget.postIds[postIndex]);
        },
      ),
    );
  }
}
