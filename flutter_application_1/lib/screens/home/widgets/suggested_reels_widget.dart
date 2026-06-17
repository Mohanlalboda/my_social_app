// lib/screens/home/widgets/suggested_reels_widget.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 🌟 THE FIX
import 'home_reel_card.dart';

class SuggestedReelsWidget extends StatefulWidget {
  final bool isDark;
  const SuggestedReelsWidget({super.key, required this.isDark});

  @override
  State<SuggestedReelsWidget> createState() => _SuggestedReelsWidgetState();
}

class _SuggestedReelsWidgetState extends State<SuggestedReelsWidget> {
  Future<List<Map<String, dynamic>>> _fetchSuggestedReels() async {
    List<Map<String, dynamic>> allReels = [];
    try {
      var reelsSnap = await FirebaseFirestore.instance
          .collection('reels')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();
      for (var doc in reelsSnap.docs) {
        var data = Map<String, dynamic>.from(doc.data() as dynamic);
        data['id'] = doc.id;
        allReels.add(data);
      }

      var postsSnap = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();
      for (var doc in postsSnap.docs) {
        var data = Map<String, dynamic>.from(doc.data() as dynamic);
        bool isVideo =
            data['isReel'] == true ||
            data['type'] == 'video' ||
            data['type'] == 'reel' ||
            data.containsKey('videoUrl');

        if (isVideo) {
          data['id'] = doc.id;
          allReels.add(data);
        }
      }

      allReels.sort((a, b) {
        var aTime = a['timestamp'] ?? a['datePublished'];
        var bTime = b['timestamp'] ?? b['datePublished'];
        if (aTime == null || bTime == null) return 0;

        DateTime dtA = (aTime is Timestamp)
            ? aTime.toDate()
            : (DateTime.tryParse(aTime.toString()) ??
                  DateTime.fromMillisecondsSinceEpoch(0));
        DateTime dtB = (bTime is Timestamp)
            ? bTime.toDate()
            : (DateTime.tryParse(bTime.toString()) ??
                  DateTime.fromMillisecondsSinceEpoch(0));

        return dtB.compareTo(dtA);
      });

      final uniqueIds = <String>{};
      allReels.retainWhere((x) => uniqueIds.add(x['id']));
    } catch (e) {
      debugPrint("Error fetching suggested reels: $e");
    }

    return allReels.take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: widget.isDark ? Colors.grey[900] : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 5),
            child: Row(
              children: [
                Icon(
                  Icons.video_library_outlined,
                  color: Colors.pinkAccent,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  "Suggested Reels",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 250,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchSuggestedReels(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.pinkAccent),
                  );
                if (!snapshot.hasData || snapshot.data!.isEmpty)
                  return const SizedBox();

                var reels = snapshot.data!;

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: reels.length,
                  itemBuilder: (context, index) {
                    var reelData = reels[index];

                    String ownerId =
                        reelData['ownerId'] ?? reelData['uid'] ?? '';
                    if (ownerId.isEmpty) return const SizedBox.shrink();

                    String thumb =
                        reelData['thumbnailUrl'] ?? reelData['coverUrl'] ?? '';
                    if (thumb.isEmpty) {
                      List mediaList =
                          reelData['postUrls'] ?? reelData['postData'] ?? [];
                      if (mediaList.isNotEmpty &&
                          mediaList[0].toString().contains('.jpg'))
                        thumb = mediaList[0];
                    }

                    int viewsCount =
                        (reelData['seenBy'] as List?)?.length ??
                        (reelData['viewedBy'] as List?)?.length ??
                        (reelData['likes'] as List?)?.length ??
                        0;

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                backgroundColor: widget.isDark
                                    ? Colors.black
                                    : Colors.white,
                                iconTheme: IconThemeData(
                                  color: widget.isDark
                                      ? Colors.white
                                      : Colors.black,
                                ),
                                title: Text(
                                  'Reel 🎬',
                                  style: TextStyle(
                                    color: widget.isDark
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              body: HomeReelCard(
                                reelData: reelData,
                                reelId: reelData['id'],
                                isActive: true,
                              ),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 140,
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? Colors.grey[850]
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              thumb.isNotEmpty
                                  // 🌟 THE FIX: Cache Reel Thumbnails
                                  ? CachedNetworkImage(
                                      imageUrl: thumb,
                                      fit: BoxFit.cover,
                                      errorWidget: (c, e, s) => Container(
                                        color: widget.isDark
                                            ? Colors.black
                                            : Colors.grey[400],
                                        child: const Icon(
                                          Icons.ondemand_video,
                                          color: Colors.white54,
                                          size: 50,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: widget.isDark
                                          ? Colors.black
                                          : Colors.grey[400],
                                      child: const Icon(
                                        Icons.ondemand_video,
                                        color: Colors.white54,
                                        size: 50,
                                      ),
                                    ),

                              const Center(
                                child: Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),

                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(150),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "$viewsCount",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
