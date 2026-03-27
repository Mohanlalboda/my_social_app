// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'single_reel_screen.dart';
import 'scrolling_posts_screen.dart';
import '../widgets/safe_elements.dart';
import 'user_list_screen.dart';
import 'chat_screen.dart';

class OtherUserProfileScreen extends StatefulWidget {
  final String userId;
  const OtherUserProfileScreen({super.key, required this.userId});

  @override
  State<OtherUserProfileScreen> createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  void _showFullProfilePic(String base64String, String fallbackName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SafeProfilePic(
              base64String: base64String,
              radius: 150,
              fallbackText: fallbackName.isNotEmpty ? fallbackName[0] : "U",
            ),
            const SizedBox(height: 20),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleFollow(bool isFollowing) async {
    var userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId);
    var myRef = FirebaseFirestore.instance.collection('users').doc(currentUid);

    if (isFollowing) {
      await userRef.update({
        'followers': FieldValue.arrayRemove([currentUid]),
      });
      await myRef.update({
        'following': FieldValue.arrayRemove([widget.userId]),
      });
    } else {
      await userRef.update({
        'followers': FieldValue.arrayUnion([currentUid]),
      });
      await myRef.update({
        'following': FieldValue.arrayUnion([widget.userId]),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData)
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );

          var userData =
              userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          String name = userData['username'] ?? "User";
          String bio = userData['bio'] ?? "";
          List followers = userData['followers'] ?? [];
          List following = userData['following'] ?? [];

          bool isPrivate = userData['isPrivate'] ?? false;
          bool isFollowing = followers.contains(currentUid);
          bool isLockedOut = isPrivate && !isFollowing;

          return Scaffold(
            backgroundColor: isDark ? Colors.black : Colors.white,
            appBar: AppBar(
              backgroundColor: isDark ? Colors.black : Colors.white,
              elevation: 0,
              iconTheme: IconThemeData(
                color: isDark ? Colors.white : Colors.black,
              ),
              title: Row(
                children: [
                  if (isPrivate) ...[
                    Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => _showFullProfilePic(
                                  userData['profilePic'] ?? "",
                                  name,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  child: SafeProfilePic(
                                    base64String: userData['profilePic'],
                                    radius: 40,
                                    fallbackText: name.isNotEmpty
                                        ? name[0]
                                        : "U",
                                  ),
                                ),
                              ),
                              Expanded(
                                child: StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('posts')
                                      .where(
                                        'ownerId',
                                        isEqualTo: widget.userId,
                                      )
                                      .snapshots(),
                                  builder: (context, postSnapshot) {
                                    int postCount = postSnapshot.hasData
                                        ? postSnapshot.data!.docs.length
                                        : 0;
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _StatColumn(
                                          num: postCount.toString(),
                                          label: "Posts",
                                        ),
                                        GestureDetector(
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => UserListScreen(
                                                title: "Followers",
                                                userIds: followers,
                                              ),
                                            ),
                                          ),
                                          child: _StatColumn(
                                            num: followers.length.toString(),
                                            label: "Followers",
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => UserListScreen(
                                                title: "Following",
                                                userIds: following,
                                              ),
                                            ),
                                          ),
                                          child: _StatColumn(
                                            num: following.length.toString(),
                                            label: "Following",
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              if (bio.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  bio,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 15),

                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          _toggleFollow(isFollowing),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isFollowing
                                            ? (isDark
                                                  ? Colors.grey[900]
                                                  : Colors.grey[200])
                                            : Colors.blue,
                                        foregroundColor: isFollowing
                                            ? (isDark
                                                  ? Colors.white
                                                  : Colors.black)
                                            : Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        isFollowing ? "Following" : "Follow",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      // 🌟 మ్యాజిక్: ఇక్కడ కరెక్ట్ వేరియబుల్స్ (receiverId) వాడాం!
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ChatScreen(
                                            receiverId: widget.userId,
                                            receiverName: name,
                                            receiverPic:
                                                userData['profilePic'] ?? "",
                                          ),
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDark
                                            ? Colors.grey[900]
                                            : Colors.grey[200],
                                        foregroundColor: isDark
                                            ? Colors.white
                                            : Colors.black,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        "Message",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 25),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (isLockedOut)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 50),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? Colors.white30 : Colors.grey,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.lock_outline,
                                size: 50,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              "This account is private",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "Follow to see their photos and videos.",
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white54
                                    : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPersistentHeader(
                      delegate: _SliverAppBarDelegate(
                        TabBar(
                          indicatorColor: isDark ? Colors.white : Colors.black,
                          indicatorWeight: 1,
                          labelColor: isDark ? Colors.white : Colors.black,
                          unselectedLabelColor: Colors.grey,
                          tabs: const [
                            Tab(icon: Icon(Icons.grid_on, size: 26)),
                            Tab(
                              icon: Icon(
                                Icons.smart_display_outlined,
                                size: 30,
                              ),
                            ),
                          ],
                        ),
                        isDark ? Colors.black : Colors.white,
                      ),
                      pinned: true,
                    ),
                ];
              },
              body: isLockedOut
                  ? const SizedBox()
                  : TabBarView(
                      children: [
                        _buildPostGrid(
                          FirebaseFirestore.instance
                              .collection('posts')
                              .where('ownerId', isEqualTo: widget.userId)
                              .where('type', isEqualTo: 'image')
                              .snapshots(),
                        ),
                        _buildReelsGrid(
                          FirebaseFirestore.instance
                              .collection('posts')
                              .where('type', isEqualTo: 'video')
                              .where('ownerId', isEqualTo: widget.userId)
                              .snapshots(),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReelsGrid(Stream<QuerySnapshot> stream) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var reels = snapshot.data!.docs;
        if (reels.isEmpty) return const Center(child: Text("No Reels yet. 🎬"));

        return GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.56,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
          ),
          itemCount: reels.length,
          itemBuilder: (context, i) {
            var reelData = reels[i].data() as Map<String, dynamic>;
            String reelId = reelData['postId'] ?? reels[i].id;
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SingleReelScreen(reelId: reelId),
                ),
              ),
              child: Container(
                color: Colors.grey[900],
                child: const Center(
                  child: Icon(Icons.play_arrow, color: Colors.white, size: 30),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPostGrid(
    Stream<QuerySnapshot> stream, {
    bool shrinkWrap = false,
    ScrollPhysics? physics,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        var posts = snapshot.data?.docs ?? [];
        if (posts.isEmpty) return const Center(child: Text("No posts found."));
        List<String> postIds = posts.map((doc) => doc.id).toList();

        return GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: shrinkWrap,
          physics: physics ?? const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
          ),
          itemCount: posts.length,
          itemBuilder: (context, i) {
            var postData = posts[i].data() as Map<String, dynamic>;
            String thumbnail =
                (postData['postData'] is List &&
                    (postData['postData'] as List).isNotEmpty)
                ? postData['postData'][0].toString()
                : postData['postData']?.toString() ?? "";
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ScrollingPostsScreen(postIds: postIds, initialIndex: i),
                ),
              ),
              child: SafeImage(base64String: thumbnail),
            );
          },
        );
      },
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String num;
  final String label;
  const _StatColumn({required this.num, required this.label});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          num,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar, this._color);
  final TabBar _tabBar;
  final Color _color;
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Container(color: _color, child: _tabBar);
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
