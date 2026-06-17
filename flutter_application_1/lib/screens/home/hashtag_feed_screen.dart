import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 🌟 THE FIX
import '../../widgets/post_card.dart';
import '../../models/post_model.dart';

class HashtagFeedScreen extends StatefulWidget {
  final String hashtag;
  const HashtagFeedScreen({super.key, required this.hashtag});

  @override
  State<HashtagFeedScreen> createState() => _HashtagFeedScreenState();
}

class _HashtagFeedScreenState extends State<HashtagFeedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final String cleanHashtag = widget.hashtag.toLowerCase().trim();

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          widget.hashtag,
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: textColor,
          labelColor: textColor,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.grid_on_rounded), text: "Posts 📸"),
            Tab(icon: Icon(Icons.movie_creation_outlined), text: "Reels 🎬"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where('hashtags', arrayContains: cleanHashtag)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(
                  child: CircularProgressIndicator(color: Colors.blueAccent),
                );
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                return const Center(
                  child: Text(
                    'No posts with this hashtag yet! 🏜️',
                    style: TextStyle(color: Colors.grey),
                  ),
                );

              return GridView.builder(
                padding: const EdgeInsets.all(2),
                itemCount: snapshot.data!.docs.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                itemBuilder: (context, index) {
                  var postDoc = snapshot.data!.docs[index];
                  PostModel post = PostModel.fromSnap(postDoc);

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(
                              backgroundColor: isDark
                                  ? Colors.black
                                  : Colors.white,
                              iconTheme: IconThemeData(color: textColor),
                              title: const Text(
                                'Post',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              elevation: 0.5,
                            ),
                            body: SingleChildScrollView(
                              child: PostCard(post: post),
                            ),
                          ),
                        ),
                      );
                    },
                    // 🌟 THE FIX: Image Caching applied to grid
                    child: CachedNetworkImage(
                      imageUrl: post.postUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: Colors.grey[800]),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.error),
                    ),
                  );
                },
              );
            },
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reels')
                .where('hashtags', arrayContains: cleanHashtag)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(
                  child: CircularProgressIndicator(color: Colors.blueAccent),
                );
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                return const Center(
                  child: Text(
                    'No reels with this hashtag yet! 🎬',
                    style: TextStyle(color: Colors.grey),
                  ),
                );

              return GridView.builder(
                padding: const EdgeInsets.all(2),
                itemCount: snapshot.data!.docs.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                  childAspectRatio: 0.7,
                ),
                itemBuilder: (context, index) {
                  return Container(
                    color: isDark ? Colors.grey[900] : Colors.grey[200],
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
