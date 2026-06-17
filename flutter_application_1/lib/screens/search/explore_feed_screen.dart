// lib/screens/search/explore_feed_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../home/widgets/home_reel_card.dart';
import '../home/widgets/home_post_card.dart';
import '../../helpers/ad_helper.dart';
import '../../widgets/my_native_ad_widget.dart';

class ExploreFeedScreen extends StatefulWidget {
  final List<dynamic> allDocs;
  final int initialIndex;
  // 🌟 parent నుండి కొత్త లిస్ట్ తెచ్చుకునే ఫంక్షన్
  final Future<List<dynamic>> Function()? onLoadMore;

  const ExploreFeedScreen({
    super.key,
    required this.allDocs,
    required this.initialIndex,
    this.onLoadMore,
  });

  @override
  State<ExploreFeedScreen> createState() => _ExploreFeedScreenState();
}

class _ExploreFeedScreenState extends State<ExploreFeedScreen> {
  late PageController _pageController;
  final String _currentUid = FirebaseAuth.instance.currentUser!.uid;

  final Set<int> _shownInterstitialIndices = {};

  List<dynamic> _localDocs = [];
  bool _isLoadingMore = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _localDocs = List.from(widget.allDocs);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    AdHelper.loadInterstitial();
    _updateViewCount(widget.initialIndex);
  }

  void _updateViewCount(int index) {
    if (index >= _localDocs.length) return;
    var item = _localDocs[index];
    Map<String, dynamic> docData;
    String docId = '';

    if (item is DocumentSnapshot) {
      docData = item.data() as Map<String, dynamic>;
      docId = item.id;
    } else {
      docData = item as Map<String, dynamic>;
      docId = docData['id'] ?? docData['postId'] ?? '';
    }
    if (docId.isEmpty) return;

    bool isReelItem =
        docData['isReel'] == true ||
        docData['type'] == 'video' ||
        docData['type'] == 'reel' ||
        docData.containsKey('videoUrl');
    String collection = isReelItem ? 'reels' : 'posts';

    FirebaseFirestore.instance
        .collection(collection)
        .doc(docId)
        .update({
          'viewedBy': FieldValue.arrayUnion([_currentUid]),
        })
        .catchError((e) => debugPrint("Error updating seen: $e"));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[200],
      appBar: AppBar(
        title: const Text(
          'Explore',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? Colors.black : Colors.white,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        elevation: 0.5,
      ),
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _pageController,
        itemCount: _localDocs.length,
        onPageChanged: (index) async {
          if (!mounted) return;
          setState(() => _currentIndex = index);
          _updateViewCount(index);

          // 12వ పోస్ట్ కి యాడ్ రూల్
          if (index > 0 &&
              index % 12 == 0 &&
              !_shownInterstitialIndices.contains(index)) {
            _shownInterstitialIndices.add(index);
            AdHelper.showInterstitial();
            AdHelper.loadInterstitial();
          }

          // 🌟 THE FIX: ఎండ్ కి వస్తున్నప్పుడు (చివరి 3 పోస్టుల ముందే) ఆటోమేటిక్ గా కొత్త 12 పోస్టులను వెనక నుండి లాగి లిస్ట్ కి అతికిస్తుంది!
          if (index >= _localDocs.length - 3 &&
              !_isLoadingMore &&
              widget.onLoadMore != null) {
            _isLoadingMore = true;
            List<dynamic> newItems = await widget.onLoadMore!();
            if (newItems.isNotEmpty && mounted) {
              setState(() {
                // పాత వాటికి డూప్లికేట్స్ లేకుండా కొత్తవి కలుపుతున్నాం
                for (var item in newItems) {
                  String newId = (item is DocumentSnapshot)
                      ? item.id
                      : (item['id'] ?? '');
                  if (!_localDocs.any((existing) {
                    String existingId = (existing is DocumentSnapshot)
                        ? existing.id
                        : (existing['id'] ?? '');
                    return existingId == newId;
                  })) {
                    _localDocs.add(item);
                  }
                }
              });
            }
            _isLoadingMore = false;
          }
        },
        itemBuilder: (context, index) {
          if (index >= _localDocs.length) return const SizedBox();

          var item = _localDocs[index];
          Map<String, dynamic> data;
          String docId = '';

          if (item is DocumentSnapshot) {
            data = item.data() as Map<String, dynamic>;
            docId = item.id;
          } else {
            data = item as Map<String, dynamic>;
            docId = data['id'] ?? data['postId'] ?? '';
          }

          bool isReelItem =
              data['isReel'] == true ||
              data['type'] == 'video' ||
              data['type'] == 'reel' ||
              data.containsKey('videoUrl');

          Widget itemWidget;

          if (isReelItem) {
            itemWidget = Container(
              color: Colors.black,
              child: HomeReelCard(
                reelData: data,
                reelId: docId,
                isActive: _currentIndex == index,
              ),
            );
          } else {
            itemWidget = SingleChildScrollView(
              child: HomePostCard(postData: data, postId: docId),
            );
          }

          // 5వ పోస్ట్ కి నేటివ్ యాడ్ రూల్
          if (index > 0 && index % 5 == 0) {
            return Column(
              children: [
                Expanded(child: itemWidget),
                const MyNativeAdWidget(),
              ],
            );
          }

          return itemWidget;
        },
      ),
    );
  }
}
