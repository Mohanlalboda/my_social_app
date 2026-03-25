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
        // 🌟 పబ్లిక్ పోస్ట్‌లు మాత్రమే ఎక్స్‌ప్లోర్ లో రావాలి కదా?
        if (data['isPublic'] == true || data['isPublic'] == null) {
          data['item_type'] = 'post';
          data['id'] = doc.id;
          allContent.add(data);
        }
      }

      var reelsSnap = await FirebaseFirestore.instance
          .collection('reels')
          .limit(20)
          .get();
      for (var doc in reelsSnap.docs) {
        var data = doc.data();
        if (data['isPublic'] == true || data['isPublic'] == null) {
          data['item_type'] = 'reel';
          data['id'] = doc.id;
          allContent.add(data);
        }
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
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        title: TextFormField(
          controller: searchController,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: 'Search for a user...',
            hintStyle: const TextStyle(color: Colors.grey),
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
            fillColor: isDark ? Colors.grey[900] : Colors.grey.shade200,
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
    bool isDark = Theme.of(context).brightness == Brightness.dark;

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
              leading: SafeProfilePic(
                base64String: userData['profilePic'],
                radius: 20,
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

            // 🌟 FIX: ఇక్కడ List లోపల ఉన్న మొదటి ఫోటోని తీసుకునే లాజిక్ రాశాను
            String thumbnail = "";
            if (!isReel) {
              if (item['postData'] is List &&
                  (item['postData'] as List).isNotEmpty) {
                thumbnail = item['postData'][0].toString();
              } else {
                thumbnail = item['postData']?.toString() ?? "";
              }
            }

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
                      : (thumbnail.startsWith('http')
                            ? Image.network(
                                thumbnail,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.broken_image),
                                ),
                              )
                            : SafeImage(
                                base64String: thumbnail,
                              )), // పాత Base64 సపోర్ట్ కోసం

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

                  // 🌟 మల్టిపుల్ ఇమేజెస్ ఉన్నాయని గుర్తు కోసం కార్నర్ లో చిన్న ఐకాన్
                  if (!isReel &&
                      item['postData'] is List &&
                      (item['postData'] as List).length > 1)
                    const Positioned(
                      top: 5,
                      right: 5,
                      child: Icon(
                        Icons.layers, // మల్టిపుల్ ఫోటోల ఐకాన్
                        color: Colors.white,
                        size: 18,
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
