import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/safe_elements.dart';

class StoryScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const StoryScreen({super.key, required this.user});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

// 🌟 AnimationController వాడటానికి SingleTickerProviderStateMixin కావాలి
class _StoryScreenState extends State<StoryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final PageController _pageController = PageController();

  int _currentIndex = 0;
  List<QueryDocumentSnapshot> _stories = [];

  @override
  void initState() {
    super.initState();
    // 🌟 ప్రతి స్టోరీకి 5 సెకన్ల టైమర్
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory(); // టైమర్ అవ్వగానే నెక్స్ట్ స్టోరీకి వెళ్ళు
      }
    });
    _loadStories();
  }

  void _loadStories() async {
    var snapshot = await FirebaseFirestore.instance
        .collection('stories')
        .where('ownerId', isEqualTo: widget.user['uid'])
        .orderBy('timestamp') // పాతవి ముందు, కొత్తవి తర్వాత
        .get();

    if (mounted) {
      setState(() {
        _stories = snapshot.docs;
      });
      if (_stories.isNotEmpty) {
        _animationController.forward(); // డేటా రాగానే టైమర్ స్టార్ట్ చేయి
      }
    }
  }

  void _nextStory() {
    if (_currentIndex < _stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeIn,
      );
      _animationController.reset();
      _animationController.forward();
    } else {
      // 🌟 స్టోరీస్ అన్నీ అయిపోతే క్లోజ్ చేయి
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeIn,
      );
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _stories.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : GestureDetector(
              // 🌟 స్క్రీన్ మీద ఎక్కడ నొక్కినా ఆపరేట్ అయ్యే లాజిక్
              onTapDown: (details) {
                final screenWidth = MediaQuery.of(context).size.width;
                if (details.globalPosition.dx < screenWidth / 3) {
                  _previousStory(); // ఎడమవైపు నొక్కితే వెనక్కి
                } else {
                  _nextStory(); // కుడివైపు నొక్కితే ముందుకు
                }
              },
              onLongPress: () =>
                  _animationController.stop(), // నొక్కి పట్టుకుంటే ఆగుతుంది
              onLongPressUp: () => _animationController
                  .forward(), // వదిలేస్తే మళ్ళీ రన్ అవుతుంది
              child: Stack(
                children: [
                  // 1. 🌟 స్టోరీ ఫోటోలు
                  PageView.builder(
                    controller: _pageController,
                    physics:
                        const NeverScrollableScrollPhysics(), // యూజర్ స్వైప్ చేయకుండా
                    itemCount: _stories.length,
                    itemBuilder: (context, index) {
                      var storyData =
                          _stories[index].data() as Map<String, dynamic>;
                      return SizedBox(
                        height: double.infinity,
                        width: double.infinity,
                        child: SafeImage(base64String: storyData['storyData']),
                      );
                    },
                  ),

                  // 2. 🌟 పైన నల్లటి షాడో (టెక్స్ట్ మరియు X బటన్ క్లియర్ గా కనిపించడానికి)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 100,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                    ),
                  ),

                  // 3. 🌟 ప్రోగ్రెస్ బార్ (Progress Bar) & X మార్క్
                  Positioned(
                    top: 50,
                    left: 10,
                    right: 10,
                    child: Column(
                      children: [
                        // గీతలు (Progress indicators)
                        Row(
                          children: List.generate(_stories.length, (index) {
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2.0,
                                ),
                                child: AnimatedBuilder(
                                  animation: _animationController,
                                  builder: (context, child) {
                                    double progress = 0.0;
                                    if (index < _currentIndex) {
                                      progress =
                                          1.0; // పూర్తయినవి ఫుల్ గా ఉంటాయి
                                    } else if (index == _currentIndex) {
                                      progress = _animationController
                                          .value; // రన్ అవుతున్నది
                                    }
                                    return LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: Colors.white38,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                      minHeight: 3,
                                    );
                                  },
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 10),

                        // 4. 🌟 ప్రొఫైల్ ఫోటో, పేరు మరియు X బటన్
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SafeProfilePic(
                                  base64String: widget.user['profilePic'],
                                  radius: 18,
                                  fallbackText:
                                      (widget.user['username'] != null &&
                                          widget.user['username']
                                              .toString()
                                              .trim()
                                              .isNotEmpty)
                                      ? widget.user['username'][0].toUpperCase()
                                      : "U",
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  widget.user['username'] ?? "User",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            // ❌ క్లోజ్ బటన్
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 30,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
