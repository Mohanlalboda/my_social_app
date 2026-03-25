// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:video_player/video_player.dart';

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

  // 🌟 ఎక్స్‌ప్లోర్ కంటెంట్ (Posts & Reels) తెచ్చుకునే ఫంక్షన్
  Future<List<Map<String, dynamic>>> getExploreContent() async {
    List<Map<String, dynamic>> allContent = [];
    try {
      var postsSnap = await FirebaseFirestore.instance
          .collection('posts')
          .limit(20)
          .get();
      for (var doc in postsSnap.docs) {
        var data = doc.data();
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
        titleSpacing: 10,
        title: TextFormField(
          controller: searchController,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: 'Search for a user...',
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
      body: isShowUsers ? _buildUserSearchStream() : _buildExploreGrid(),
    );
  }

  // 🌟 1. యూజర్ సెర్చ్ సెక్షన్ (Case-Insensitive)
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

  // 🌟 2. ఇన్‌స్టాగ్రామ్ స్టైల్ గ్రిడ్ వ్యూ (Fixed Overlap)
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
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.only(top: 2),
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
              // 🌟 OVERLAP FIX: ClipRRect వాడటం వల్ల ఇమేజ్ పక్క బాక్స్ లోకి రాదు
              child: ClipRRect(
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: isReel
                          ? ReelGridPreview(videoUrl: item['videoUrl'] ?? '')
                          : (thumbnail.startsWith('http')
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
                                  )),
                    ),

                    // షాడో గ్రేడియంట్ (Latest .withValues standard)
                    Positioned(
                      top: 0,
                      right: 0,
                      left: 0,
                      height: 35,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ఐకాన్స్
                    Positioned(
                      top: 5,
                      right: 5,
                      child: isReel
                          ? const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 24,
                            )
                          : (item['postData'] is List &&
                                (item['postData'] as List).length > 1)
                          ? const Icon(
                              Icons.filter_none,
                              color: Colors.white,
                              size: 16,
                            )
                          : const SizedBox(),
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

// 🌟 REELS PREVIEW WIDGET (Fixed Overlap with ClipRect)
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
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    if (widget.videoUrl.isNotEmpty && widget.videoUrl.startsWith('http')) {
      _player.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videoUrl.isEmpty || !widget.videoUrl.startsWith('http'))
      return Container(color: Colors.grey[900]);

    return _isInitialized
        ? SizedBox.expand(
            // 🌟 REEL OVERLAP FIX: ClipRect వాడాం
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
