// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/safe_elements.dart';
import 'other_user_profile_screen.dart';
import 'scrolling_posts_screen.dart';
import 'single_reel_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController searchController = TextEditingController();
  bool isShowUsers = false;

  Future<List<Map<String, dynamic>>> getExploreContent() async {
    List<Map<String, dynamic>> allContent = [];
    try {
      var postsSnap = await FirebaseFirestore.instance
          .collection('posts')
          .limit(20)
          .get();
      for (var doc in postsSnap.docs) {
        var data = doc.data();
        data['item_type'] = 'post';
        data['id'] = doc.id;
        allContent.add(data);
      }

      var reelsSnap = await FirebaseFirestore.instance
          .collection('reels')
          .limit(20)
          .get();
      for (var doc in reelsSnap.docs) {
        var data = doc.data();
        data['item_type'] = 'reel';
        data['id'] = doc.id;
        allContent.add(data);
      }

      allContent.shuffle();
    } catch (e) {
      debugPrint("Explore Fetch Error: $e");
    }
    return allContent;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: TextFormField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Search for a user...',
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            suffixIcon: isShowUsers
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () => setState(() {
                      searchController.clear();
                      isShowUsers = false;
                    }),
                  )
                : null,
            filled: true,
            fillColor: Colors.grey.shade200,
            contentPadding: const EdgeInsets.all(8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          onFieldSubmitted: (String _) => setState(
            () => isShowUsers = searchController.text.trim().isNotEmpty,
          ),
          onChanged: (String text) {
            if (text.isEmpty) setState(() => isShowUsers = false);
          },
        ),
      ),
      body: isShowUsers ? _buildUserSearchStream() : _buildExploreGrid(),
    );
  }

  Widget _buildUserSearchStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where(
            'username',
            isGreaterThanOrEqualTo: searchController.text.trim(),
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var users = snapshot.data!.docs;
        if (users.isEmpty)
          return const Center(
            child: Text(
              "No users found.",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            var userData = users[index].data() as Map<String, dynamic>;
            String username = userData['username'] ?? 'User';

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                username,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                userData['bio'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

  Widget _buildExploreGrid() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: getExploreContent(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return const Center(
            child: Text(
              "No posts or reels yet. Follow some people! 🌟",
              style: TextStyle(color: Colors.grey),
            ),
          );

        List<Map<String, dynamic>> exploreData = snapshot.data!;
        List<String> onlyPostIds = exploreData
            .where((item) => item['item_type'] == 'post')
            .map((item) => item['id'] as String)
            .toList();

        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 1,
          ),
          itemCount: exploreData.length,
          itemBuilder: (context, index) {
            var item = exploreData[index];
            bool isReel = item['item_type'] == 'reel';

            return GestureDetector(
              onTap: () {
                if (isReel) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          SingleReelScreen(reelId: item['id']),
                    ),
                  );
                } else {
                  int actualIndex = onlyPostIds.indexOf(item['id']);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ScrollingPostsScreen(
                        postIds: onlyPostIds,
                        initialIndex: actualIndex != -1 ? actualIndex : 0,
                      ),
                    ),
                  );
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  isReel
                      ? Container(color: Colors.black87)
                      : SafeImage(base64String: item['postData']),
                  if (isReel)
                    const Positioned(
                      top: 5,
                      right: 5,
                      child: Icon(
                        Icons.video_library,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  if (isReel)
                    const Center(
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white54,
                        size: 40,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
