// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../widgets/safe_elements.dart';
import '../../widgets/cached_media_widget.dart';

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

    _pageController.addListener(() {
      if (_pageController.position.pixels >=
              _pageController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _fetchReels();
      }
    });

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

  Future<void> _fetchReels() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      Query query;

      if (widget.reelIds != null && widget.reelIds!.isNotEmpty) {
        query = FirebaseFirestore.instance
            .collection('reels')
            .where(FieldPath.documentId, whereIn: widget.reelIds)
            .orderBy('timestamp', descending: true);
      } else {
        query = FirebaseFirestore.instance
            .collection('reels')
            .orderBy('timestamp', descending: true)
            .limit(5);

        if (_lastDoc != null) {
          query = query.startAfterDocument(_lastDoc!);
        }
      }

      var snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastDoc = snapshot.docs.last;
        setState(() {
          _reels.addAll(snapshot.docs);
        });
      }

      if (snapshot.docs.length < 5 || (widget.reelIds != null)) {
        _hasMore = false;
      }
    } catch (e) {
      debugPrint("Fetch Reels Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _likeReel(String reelId, List likes) async {
    bool isLiked = likes.contains(currentUid);
    try {
      if (isLiked) {
        await FirebaseFirestore.instance.collection('reels').doc(reelId).update(
          {
            'likes': FieldValue.arrayRemove([currentUid]),
          },
        );
      } else {
        await FirebaseFirestore.instance.collection('reels').doc(reelId).update(
          {
            'likes': FieldValue.arrayUnion([currentUid]),
          },
        );
      }
    } catch (e) {
      debugPrint("Like Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_reels.isEmpty && _isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_reels.isEmpty && !_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            "No Reels found! 😢",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _reels.length,
        itemBuilder: (context, index) {
          var reelDoc = _reels[index];
          var data = reelDoc.data() as Map<String, dynamic>;
          String reelId = reelDoc.id;
          String videoUrl = data['mediaUrl'] ?? '';
          String ownerId = data['ownerId'] ?? '';
          String description = data['description'] ?? '';
          List likes = data['likes'] ?? [];
          bool isLiked = likes.contains(currentUid);

          return Stack(
            fit: StackFit.expand,
            children: [
              // 🌟 1. వీడియో ప్లేయర్ (Background)
              CachedMediaWidget(
                mediaUrl: videoUrl,
                type: 'video',
                isGrid: false,
              ),

              // 🌟 2. కుడివైపు యాక్షన్ బటన్స్ (Right Side Panel)
              Positioned(
                bottom: 20,
                right: 10,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Profile Picture with Follow/Plus Icon
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(ownerId)
                          .get(),
                      builder: (context, userSnap) {
                        String profilePic = '';
                        String fallback = 'U';
                        if (userSnap.hasData && userSnap.data!.exists) {
                          var userData =
                              userSnap.data!.data() as Map<String, dynamic>;
                          profilePic = userData['profilePic'] ?? '';
                          fallback = (userData['username'] ?? 'U')[0];
                        }

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: SafeProfilePic(
                                base64String: profilePic,
                                radius: 22,
                                fallbackText: fallback,
                              ),
                            ),
                            Positioned(
                              bottom: -8,
                              left: 14,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 30),

                    // Like Button
                    Column(
                      children: [
                        IconButton(
                          icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red : Colors.white,
                            size: 35,
                          ),
                          onPressed: () => _likeReel(reelId, likes),
                        ),
                        Text(
                          "${likes.length}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // Comment Button
                    Column(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.comment_outlined,
                            color: Colors.white,
                            size: 35,
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Comments coming soon!"),
                              ),
                            );
                          },
                        ),
                        const Text(
                          "0",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // Share Button
                    Column(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.send_outlined,
                            color: Colors.white,
                            size: 35,
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Share coming soon!"),
                              ),
                            );
                          },
                        ),
                        const Text(
                          "Share",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // 🌟 3. రొటేట్ అయ్యే మ్యూజిక్ ఐకాన్ (Bottom Right Corner)
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0, end: 2 * 3.14159265359),
                      duration: const Duration(seconds: 4),
                      builder: (context, double value, child) {
                        return Transform.rotate(
                          angle: value,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.music_note,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        );
                      },
                      onEnd: () {
                        // Continuous rotation trick (by updating state, but simple Tween is fine for basic effect)
                        // For infinite rotation, consider using an AnimationController in a real app
                      },
                    ),
                  ],
                ),
              ),

              // 🌟 4. కింద డిస్క్రిప్షన్ (Bottom Left Text)
              Positioned(
                bottom: 20,
                left: 15,
                right: 80, // Right panel కవర్ అవ్వకుండా
                child: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(ownerId)
                      .get(),
                  builder: (context, userSnap) {
                    String username = "User";
                    if (userSnap.hasData && userSnap.data!.exists) {
                      var userData =
                          userSnap.data!.data() as Map<String, dynamic>;
                      username = userData['username'] ?? "User";
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Username
                        Text(
                          "@$username",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Description
                        if (description.isNotEmpty)
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        const SizedBox(height: 12),

                        // Music Track Info (Scrolling Marquee style)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.music_note,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Original Audio",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // పైన వెనక్కి వెళ్లే బటన్ (Optional for For You Page, but good to have)
              Positioned(
                top: 40,
                left: 10,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
