// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../widgets/safe_elements.dart';
import '../../widgets/cached_media_widget.dart';
import '../profile/other_user_profile_screen.dart';
import '../posts/scrolling_posts_screen.dart';
import '../reels/scrolling_reels_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController searchController = TextEditingController();
  bool isShowUsers = false;
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        appBar: AppBar(
          backgroundColor: isDark ? Colors.black : Colors.white,
          elevation: 0,
          title: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[200],
              borderRadius: BorderRadius.circular(25),
            ),
            child: TextFormField(
              controller: searchController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Search for a user...',
                hintStyle: const TextStyle(color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: isShowUsers
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          searchController.clear();
                          setState(() => isShowUsers = false);
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
              ),
              onChanged: (String value) {
                setState(() {
                  isShowUsers = value.trim().isNotEmpty;
                });
              },
            ),
          ),
        ),
        body: isShowUsers
            ? _buildUserSearch()
            : Column(
                children: [
                  _buildSuggestedFriends(), // 🌟 సజెస్టెడ్ ఫ్రెండ్స్
                  const TabBar(
                    indicatorColor: Color(0xFF00E5FF),
                    labelColor: Color(0xFF00E5FF),
                    unselectedLabelColor: Colors.grey,
                    tabs: [
                      Tab(icon: Icon(Icons.grid_on), text: "Posts"),
                      Tab(icon: Icon(Icons.video_library), text: "Reels"),
                    ],
                  ),
                  Expanded(child: _buildExploreTabs()),
                ],
              ),
      ),
    );
  }

  // 🌟 1. యూజర్లను వెతికే స్క్రీన్
  Widget _buildUserSearch() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .where(
            'username',
            isGreaterThanOrEqualTo: searchController.text.trim(),
          )
          .where(
            'username',
            isLessThanOrEqualTo: '${searchController.text.trim()}\uf8ff',
          )
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              "No users found.",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var userData =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            String userId = snapshot.data!.docs[index].id;

            return ListTile(
              leading: SafeProfilePic(
                base64String: userData['profilePic'] ?? '',
                radius: 22,
                fallbackText: (userData['username'] ?? 'U')[0],
              ),
              title: Text(
                userData['username'] ?? 'User',
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
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OtherUserProfileScreen(userId: userId),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // 🌟 2. సజెస్టెడ్ ఫ్రెండ్స్ లిస్ట్
  Widget _buildSuggestedFriends() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .snapshots(),
      builder: (context, mySnapshot) {
        if (!mySnapshot.hasData) return const SizedBox();

        var myData = mySnapshot.data!.data() as Map<String, dynamic>? ?? {};
        List myFollowing = myData['following'] ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .limit(15)
              .snapshots(),
          builder: (context, usersSnapshot) {
            if (!usersSnapshot.hasData) return const SizedBox();

            var users = usersSnapshot.data!.docs
                .where((doc) => doc.id != currentUid)
                .toList();
            if (users.isEmpty) return const SizedBox();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 15, top: 10, bottom: 5),
                  child: Text(
                    "Suggested for you",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      var userData =
                          users[index].data() as Map<String, dynamic>;
                      String targetUid = users[index].id;

                      List targetFollowers = userData['followers'] ?? [];
                      int mutualCount = myFollowing
                          .where((id) => targetFollowers.contains(id))
                          .length;

                      bool isFollowing = myFollowing.contains(targetUid);

                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                OtherUserProfileScreen(userId: targetUid),
                          ),
                        ),
                        child: Container(
                          width: 120,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[900] : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SafeProfilePic(
                                base64String: userData['profilePic'] ?? '',
                                radius: 26,
                                fallbackText: (userData['username'] ?? 'U')[0]
                                    .toUpperCase(),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                userData['username'] ?? 'User',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                mutualCount > 0
                                    ? "$mutualCount mutual friends"
                                    : "Suggested",
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              SizedBox(
                                width: double.infinity,
                                height: 28,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isFollowing
                                        ? Colors.grey[300]
                                        : const Color(0xFF00E5FF),
                                    padding: EdgeInsets.zero,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  onPressed: () async {
                                    if (isFollowing) {
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(currentUid)
                                          .update({
                                            'following': FieldValue.arrayRemove(
                                              [targetUid],
                                            ),
                                          });
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(targetUid)
                                          .update({
                                            'followers': FieldValue.arrayRemove(
                                              [currentUid],
                                            ),
                                          });
                                    } else {
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(currentUid)
                                          .update({
                                            'following': FieldValue.arrayUnion([
                                              targetUid,
                                            ]),
                                          });
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(targetUid)
                                          .update({
                                            'followers': FieldValue.arrayUnion([
                                              currentUid,
                                            ]),
                                          });
                                    }
                                  },
                                  child: Text(
                                    isFollowing ? "Following" : "Follow",
                                    style: TextStyle(
                                      color: isFollowing
                                          ? Colors.black87
                                          : Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
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
              ],
            );
          },
        );
      },
    );
  }

  // 🌟 3. ఎక్స్‌ప్లోర్ ట్యాబ్స్
  Widget _buildExploreTabs() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
          );
        }

        var allDocs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return data['isPublic'] ?? true;
        }).toList();

        var imagePosts = allDocs.where((doc) {
          var type = (doc.data() as Map<String, dynamic>)['type'] ?? 'image';
          return type != 'video';
        }).toList();

        var videoReels = allDocs.where((doc) {
          var type = (doc.data() as Map<String, dynamic>)['type'] ?? 'image';
          return type == 'video';
        }).toList();

        int sortByLikes(DocumentSnapshot a, DocumentSnapshot b) {
          var dataA = a.data() as Map<String, dynamic>;
          var dataB = b.data() as Map<String, dynamic>;

          int likesA = (dataA['likes'] as List?)?.length ?? 0;
          int likesB = (dataB['likes'] as List?)?.length ?? 0;

          if (likesA == likesB) {
            Timestamp? timeA = dataA['timestamp'] as Timestamp?;
            Timestamp? timeB = dataB['timestamp'] as Timestamp?;
            if (timeA != null && timeB != null) return timeB.compareTo(timeA);
          }
          return likesB.compareTo(likesA);
        }

        imagePosts.sort(sortByLikes);
        videoReels.sort(sortByLikes);

        return TabBarView(
          children: [
            _buildGrid(imagePosts, isReelTab: false),
            _buildGrid(videoReels, isReelTab: true),
          ],
        );
      },
    );
  }

  // 🌟 4. గ్రిడ్ డిజైన్ (THE FIX IS HERE)
  Widget _buildGrid(List<DocumentSnapshot> items, {required bool isReelTab}) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          isReelTab ? "No trending reels yet." : "No trending posts yet.",
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    // 🌟 THE FIX: గ్రిడ్ లో ఉన్న అన్ని ఐటెమ్స్ యొక్క ఐడీలని ఒక లిస్ట్ లాగా తయారు చేశాం.
    List<String> allItemIds = items.map((doc) => doc.id).toList();

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(2),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isReelTab ? 2 : 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: isReelTab ? 9 / 16 : 1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        var data = items[index].data() as Map<String, dynamic>;
        String type = data['type'] ?? 'image';
        int likesCount = (data['likes'] as List?)?.length ?? 0;

        String mediaUrl = "";
        if (data['postData'] is List && (data['postData'] as List).isNotEmpty) {
          mediaUrl = data['postData'][0].toString();
        } else if (data['storyUrl'] != null) {
          mediaUrl = data['storyUrl'].toString();
        }

        return GestureDetector(
          onTap: () {
            // 🌟 THE FIX: కేవలం ఒక్క ID కాకుండా, మొత్తం లిస్ట్ ని, అలాగే ఏ ఐటెమ్ నొక్కాడో ఆ ఇండెక్స్ ని పంపుతున్నాం
            if (isReelTab) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScrollingReelsScreen(
                    reelIds: allItemIds, // అన్ని రీల్స్ ఐడీలు
                    initialIndex: index, // ఏది నొక్కాడో దాని పొజిషన్
                  ),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScrollingPostsScreen(
                    postIds: allItemIds, // అన్ని పోస్ట్‌ల ఐడీలు
                    initialIndex: index, // ఏది నొక్కాడో దాని పొజిషన్
                  ),
                ),
              );
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedMediaWidget(mediaUrl: mediaUrl, type: type, isGrid: true),

              // గ్రేడియంట్ షాడో
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 30,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
              ),

              // 🌟 రెడ్ హార్ట్ మరియు లైక్స్ కౌంట్
              Positioned(
                bottom: 5,
                left: 8,
                child: Row(
                  children: [
                    const Icon(
                      Icons.favorite,
                      color: Colors.redAccent,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "$likesCount",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // కలెక్షన్ ఐకాన్
              if (!isReelTab &&
                  data['postData'] is List &&
                  (data['postData'] as List).length > 1)
                const Positioned(
                  top: 5,
                  right: 5,
                  child: Icon(Icons.collections, color: Colors.white, size: 18),
                ),
            ],
          ),
        );
      },
    );
  }
}
