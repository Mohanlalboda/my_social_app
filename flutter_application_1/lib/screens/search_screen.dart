// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/safe_elements.dart';
import '../widgets/cached_media_widget.dart';
import 'other_user_profile_screen.dart';
import 'scrolling_posts_screen.dart';
import 'scrolling_reels_screen.dart';

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
      body: isShowUsers ? _buildUserSearchStream() : _buildExploreSection(),
    );
  }

  Widget _buildUserSearchStream() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    String searchText = searchController.text.trim().toLowerCase();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var users = snapshot.data!.docs.where((doc) {
          var userData = doc.data() as Map<String, dynamic>;
          String username = (userData['username'] ?? '')
              .toString()
              .toLowerCase();
          return username.contains(searchText);
        }).toList();

        if (users.isEmpty) {
          return const Center(
            child: Text(
              "No users found.",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

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
                      OtherUserProfileScreen(userId: users[index].id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildExploreSection() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get(),
      builder: (context, userSnap) {
        if (!userSnap.hasData)
          return const Center(child: CircularProgressIndicator());
        var myData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
        List myFollowing = List.from(myData['following'] ?? [])
          ..add(currentUid);

        return DefaultTabController(
          length: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSuggestedFriends(myFollowing),
              TabBar(
                indicatorColor: const Color(0xFFFD1D1D),
                labelColor: isDark ? Colors.white : Colors.black,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(icon: Icon(Icons.grid_on), text: "Trending Posts"),
                  Tab(icon: Icon(Icons.video_library), text: "Top Reels"),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildPostsGrid(myFollowing),
                    _buildReelsGrid(myFollowing),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🌟 1. Mutual Friends లాజిక్ ఇక్కడ యాడ్ చేశాం
  Widget _buildSuggestedFriends(List myFollowing) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .limit(30) // కొంచెం ఎక్కువ మందిని తీసుకుందాం ఫిల్టర్ చేయడానికి
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        var suggestedUsers = snapshot.data!.docs
            .where(
              (doc) => doc.id != currentUid && !myFollowing.contains(doc.id),
            )
            .toList();

        if (suggestedUsers.isEmpty) return const SizedBox();

        // 🌟 మ్యూచువల్ ఫ్రెండ్స్ ని బట్టి సార్టింగ్ (ఎవరికి ఎక్కువ మ్యూచువల్స్ ఉంటే వాళ్ళు ముందుకి వస్తారు)
        suggestedUsers.sort((a, b) {
          var aData = a.data() as Map<String, dynamic>;
          var bData = b.data() as Map<String, dynamic>;

          List aFollowers = aData['followers'] ?? [];
          List bFollowers = bData['followers'] ?? [];

          int aMutuals = aFollowers
              .where((id) => myFollowing.contains(id))
              .length;
          int bMutuals = bFollowers
              .where((id) => myFollowing.contains(id))
              .length;

          return bMutuals.compareTo(
            aMutuals,
          ); // ఎక్కువ ఉన్నవాళ్లు ముందు వస్తారు
        });

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
              height: 165, // మ్యూచువల్ టెక్స్ట్ కి ప్లేస్ కోసం పెంచాం
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: suggestedUsers.length > 15
                    ? 15
                    : suggestedUsers.length, // టాప్ 15 మందిని చూపిస్తాం
                itemBuilder: (context, index) {
                  var userData =
                      suggestedUsers[index].data() as Map<String, dynamic>;
                  String username = userData['username'] ?? 'User';

                  // మ్యూచువల్ ఫ్రెండ్స్ లెక్క
                  List userFollowers = userData['followers'] ?? [];
                  int mutualCount = userFollowers
                      .where((id) => myFollowing.contains(id))
                      .length;

                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OtherUserProfileScreen(
                          userId: suggestedUsers[index].id,
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
                          const SizedBox(height: 8),
                          Text(
                            username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          // 🌟 కింద "2 mutual friends" అని చూపిస్తుంది
                          Text(
                            mutualCount > 0
                                ? "$mutualCount mutuals"
                                : "New User",
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 8),
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
  }

  // ----------------------------------------------------
  // 📸 POSTS GRID (🌟 Sorted by Likes)
  // ----------------------------------------------------
  Widget _buildPostsGrid(List myFollowing) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('type', isEqualTo: 'image')
          .snapshots(), // టైమ్‌స్టాంప్ తీసేసి అన్నీ తెచ్చుకుని లైక్స్ బట్టి సార్ట్ చేద్దాం
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var posts = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          bool isPublic = data['isPublic'] ?? true;
          String ownerId = data['ownerId'];
          return isPublic || myFollowing.contains(ownerId);
        }).toList();

        // 🌟 బ్రహ్మాస్త్రం: లైక్స్ ని బట్టి సార్టింగ్ (ఎక్కువ లైక్స్ ఉన్నవి ముందు వస్తాయి)
        posts.sort((a, b) {
          var aData = a.data() as Map<String, dynamic>;
          var bData = b.data() as Map<String, dynamic>;
          int aLikes = (aData['likes'] as List?)?.length ?? 0;
          int bLikes = (bData['likes'] as List?)?.length ?? 0;
          return bLikes.compareTo(aLikes); // Descending order
        });

        List<String> postIds = posts.map((p) => p.id).toList();

        if (posts.isEmpty) {
          return const Center(
            child: Text(
              "No trending posts.",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

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

            int likesCount = (data['likes'] as List?)?.length ?? 0;

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
                          ? CachedMediaWidget(
                              mediaUrl: thumbnail,
                              type: 'image',
                            )
                          : SafeImage(
                              base64String: thumbnail,
                              fit: BoxFit.cover,
                            ),
                    ),

                    // 🌟 ఎన్ని లైక్స్ ఉన్నాయో బొమ్మ మీద చిన్నగా చూపిద్దాం
                    Positioned(
                      bottom: 5,
                      left: 5,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.favorite,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            "$likesCount",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
  // 🎬 REELS GRID (🌟 Sorted by Likes)
  // ----------------------------------------------------
  Widget _buildReelsGrid(List myFollowing) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('type', isEqualTo: 'video')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var reels = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          bool isPublic = data['isPublic'] ?? true;
          String ownerId = data['ownerId'];
          return isPublic || myFollowing.contains(ownerId);
        }).toList();

        // 🌟 రీల్స్ ని కూడా లైక్స్ బట్టి సార్ట్ చేస్తున్నాం
        reels.sort((a, b) {
          var aData = a.data() as Map<String, dynamic>;
          var bData = b.data() as Map<String, dynamic>;
          int aLikes = (aData['likes'] as List?)?.length ?? 0;
          int bLikes = (bData['likes'] as List?)?.length ?? 0;
          return bLikes.compareTo(aLikes);
        });

        List<String> reelIds = reels.map((r) => r.id).toList();

        if (reels.isEmpty) {
          return const Center(
            child: Text(
              "No trending reels.",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(top: 2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 0.65,
          ),
          itemCount: reels.length,
          itemBuilder: (context, index) {
            var data = reels[index].data() as Map<String, dynamic>;
            String videoUrl =
                (data['postData'] is List &&
                    (data['postData'] as List).isNotEmpty)
                ? data['postData'][0].toString()
                : (data['storyUrl'] ?? "");

            int likesCount = (data['likes'] as List?)?.length ?? 0;

            return GestureDetector(
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
                      child: CachedMediaWidget(
                        mediaUrl: videoUrl,
                        type: 'video',
                      ),
                    ),

                    // 🌟 ఎన్ని లైక్స్ ఉన్నాయో కింద చూపిద్దాం
                    Positioned(
                      bottom: 5,
                      left: 5,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.favorite,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            "$likesCount",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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
