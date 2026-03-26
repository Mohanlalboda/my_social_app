// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:video_player/video_player.dart';

import '../widgets/safe_elements.dart';
import 'other_user_profile_screen.dart';
import 'scrolling_posts_screen.dart';
import 'scrolling_reels_screen.dart'; // 🌟 1. కొత్తగా చేసిన ఫైల్ ఇంపోర్ట్

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController searchController = TextEditingController();
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  bool isShowUsers = false;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        titleSpacing: 10,
        title: TextFormField(
          controller: searchController,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: 'Search users...',
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 15),
            prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
            suffixIcon: isShowUsers
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                    onPressed: () => setState(() {
                      searchController.clear();
                      isShowUsers = false;
                    }),
                  )
                : null,
            filled: true,
            fillColor: isDark ? Colors.grey[900] : Colors.grey.shade200,
            contentPadding: const EdgeInsets.all(8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (String text) {
            setState(() {
              isShowUsers = text.trim().isNotEmpty;
            });
          },
        ),
      ),
      // 🌟 2. సెర్చ్ చేస్తుంటే రిజల్ట్స్, లేదంటే ఎక్స్‌ప్లోర్ (Suggestions + Tabs)
      body: isShowUsers ? _buildUserSearchStream() : _buildExploreSection(),
    );
  }

  // ----------------------------------------------------
  // 🔍 USER SEARCH STREAM
  // ----------------------------------------------------
  Widget _buildUserSearchStream() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    String searchText = searchController.text.trim().toLowerCase();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var users = snapshot.data!.docs.where((doc) {
          var userData = doc.data() as Map<String, dynamic>;
          String username = (userData['username'] ?? '')
              .toString()
              .toLowerCase();
          return username.contains(searchText);
        }).toList();

        if (users.isEmpty)
          return const Center(
            child: Text(
              "No users found.",
              style: TextStyle(color: Colors.grey),
            ),
          );

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            var userData = users[index].data() as Map<String, dynamic>;
            String username = userData['username'] ?? 'User';
            return ListTile(
              leading: SafeProfilePic(
                base64String: userData['profilePic'],
                radius: 22,
                fallbackText: username.isNotEmpty
                    ? username[0].toUpperCase()
                    : 'U',
              ),
              title: Text(
                username,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              subtitle: Text(
                userData['bio'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      OtherUserProfileScreen(uid: users[index].id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ----------------------------------------------------
  // 🌟 NEW: EXPLORE SECTION (Suggestions + Tabs)
  // ----------------------------------------------------
  Widget _buildExploreSection() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🤝 ఫాలో అవ్వడానికి సజెస్టెడ్ ఫ్రెండ్స్
          _buildSuggestedFriends(),

          // 🌟 పోస్ట్స్ మరియు రీల్స్ కోసం సపరేట్ టాబ్స్
          TabBar(
            indicatorColor: const Color(0xFFFD1D1D), // Instagram Red
            labelColor: isDark ? Colors.white : Colors.black,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(icon: Icon(Icons.grid_on), text: "Posts"),
              Tab(icon: Icon(Icons.video_library), text: "Reels"),
            ],
          ),

          // 🌟 టాబ్స్ లోపల గ్రిడ్స్
          Expanded(
            child: TabBarView(children: [_buildPostsGrid(), _buildReelsGrid()]),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // 🤝 SUGGESTED FRIENDS (కొత్త వాళ్లని పట్టుకోవడానికి)
  // ----------------------------------------------------
  Widget _buildSuggestedFriends() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const SizedBox();
        var myData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
        List myFollowing = myData['following'] ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .limit(15)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();

            // 🌟 నేను ఫాలో అవ్వని వాళ్ళని మాత్రమే ఫిల్టర్ చేస్తున్నాం
            var suggestedUsers = snapshot.data!.docs
                .where(
                  (doc) =>
                      doc.id != currentUid && !myFollowing.contains(doc.id),
                )
                .toList();

            if (suggestedUsers.isEmpty) return const SizedBox();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  child: Text(
                    "Discover People",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                SizedBox(
                  height: 150,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: suggestedUsers.length,
                    itemBuilder: (context, index) {
                      var userData =
                          suggestedUsers[index].data() as Map<String, dynamic>;
                      String username = userData['username'] ?? 'User';

                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OtherUserProfileScreen(
                              uid: suggestedUsers[index].id,
                            ),
                          ),
                        ),
                        child: Container(
                          width: 120,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[900] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SafeProfilePic(
                                base64String: userData['profilePic'],
                                radius: 35,
                                fallbackText: username.isNotEmpty
                                    ? username[0]
                                    : 'U',
                              ),
                              const SizedBox(height: 10),
                              Text(
                                username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Text(
                                  "View",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
            );
          },
        );
      },
    );
  }

  // ----------------------------------------------------
  // 📸 1. POSTS GRID
  // ----------------------------------------------------
  Widget _buildPostsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var posts = snapshot.data!.docs;
        List<String> postIds = posts.map((p) => p.id).toList();

        if (posts.isEmpty)
          return const Center(
            child: Text(
              "No posts found.",
              style: TextStyle(color: Colors.grey),
            ),
          );

        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(top: 2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 1,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            var data = posts[index].data() as Map<String, dynamic>;
            String thumbnail =
                (data['postData'] is List &&
                    (data['postData'] as List).isNotEmpty)
                ? data['postData'][0].toString()
                : data['postData']?.toString() ?? "";

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScrollingPostsScreen(
                    postIds: postIds,
                    initialIndex: index,
                  ),
                ),
              ),
              child: ClipRRect(
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: thumbnail.startsWith('http')
                          ? CachedNetworkImage(
                              imageUrl: thumbnail,
                              fit: BoxFit.cover,
                              placeholder: (c, u) =>
                                  Container(color: Colors.grey[800]),
                              errorWidget: (c, e, s) => Container(
                                color: Colors.grey[900],
                                child: const Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : SafeImage(
                              base64String: thumbnail,
                              fit: BoxFit.cover,
                            ),
                    ),
                    if (data['postData'] is List &&
                        (data['postData'] as List).length > 1)
                      const Positioned(
                        top: 5,
                        right: 5,
                        child: Icon(
                          Icons.filter_none,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ----------------------------------------------------
  // 🎬 2. REELS GRID (ఇప్పుడు స్క్రోల్ అవుతాయి!)
  // ----------------------------------------------------
  Widget _buildReelsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reels')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var reels = snapshot.data!.docs;
        // 🌟 ఇక్కడ మనం లిస్ట్ ఆఫ్ రీల్ ఐడీలు తీసుకుంటున్నాం
        List<String> reelIds = reels.map((r) => r.id).toList();

        if (reels.isEmpty)
          return const Center(
            child: Text(
              "No reels found.",
              style: TextStyle(color: Colors.grey),
            ),
          );

        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(top: 2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 1,
          ),
          itemCount: reels.length,
          itemBuilder: (context, index) {
            var data = reels[index].data() as Map<String, dynamic>;

            return GestureDetector(
              // 🌟 TRICK: ఇక్కడ పాత SingleReel స్క్రీన్ కాకుండా కొత్తగా చేసిన ScrollingReels స్క్రీన్ కి పంపుతున్నాం!
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScrollingReelsScreen(
                    reelIds: reelIds,
                    initialIndex: index,
                  ),
                ),
              ),
              child: ClipRRect(
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: ReelGridPreview(videoUrl: data['videoUrl'] ?? ''),
                    ),
                    const Positioned(
                      top: 5,
                      right: 5,
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// 🌟 REELS PREVIEW WIDGET
class ReelGridPreview extends StatefulWidget {
  final String videoUrl;
  const ReelGridPreview({super.key, required this.videoUrl});
  @override
  State<ReelGridPreview> createState() => _ReelGridPreviewState();
}

class _ReelGridPreviewState extends State<ReelGridPreview> {
  late CachedVideoPlayerPlus _player;
  bool _isInitialized = false;
  @override
  void initState() {
    super.initState();
    if (widget.videoUrl.isNotEmpty && widget.videoUrl.startsWith('http')) {
      _player = CachedVideoPlayerPlus.networkUrl(Uri.parse(widget.videoUrl));
      _player.initialize().then((_) {
        if (mounted) setState(() => _isInitialized = true);
      });
    }
  }

  @override
  void dispose() {
    if (widget.videoUrl.isNotEmpty && widget.videoUrl.startsWith('http'))
      _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videoUrl.isEmpty || !widget.videoUrl.startsWith('http'))
      return Container(color: Colors.grey[900]);
    return _isInitialized
        ? SizedBox.expand(
            child: ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _player.controller.value.size.width,
                  height: _player.controller.value.size.height,
                  child: VideoPlayer(_player.controller),
                ),
              ),
            ),
          )
        : Container(
            color: Colors.grey[900],
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey,
              ),
            ),
          );
  }
}
