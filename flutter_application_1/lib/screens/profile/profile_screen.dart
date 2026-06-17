// lib/screens/profile/profile_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import '../../services/firestore_methods.dart';
import 'add_highlight_sheet.dart';
import 'edit_profile_screen.dart';
import 'follow_list_screen.dart';
import '../chat/chat_room_screen.dart';
import 'settings_screen.dart';
import '../home/story_view_screen.dart';
import 'family_tree_screen.dart';
import '../home/widgets/home_post_card.dart';
import '../home/widgets/home_reel_card.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late String targetUid;
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  late TabController _tabController;
  bool _isBioExpanded = false;

  @override
  void initState() {
    super.initState();
    targetUid = widget.userId ?? currentUid;
    _tabController = TabController(length: 3, vsync: this);
  }

  // 🌟 THE FIX 2: పాత డేటాలో ఉన్న అన్ని రకాల వ్యూస్ ఫీల్డ్స్ ని చెక్ చేసి పక్కాగా కౌంట్ లాగే ఫంక్షన్!
  int _getViewsCount(Map<String, dynamic> data) {
    int count = 0;

    if (data['seenBy'] is List)
      count = (data['seenBy'] as List).length;
    else if (data['viewedBy'] is List)
      count = (data['viewedBy'] as List).length;
    else if (data['viewers'] is List)
      count = (data['viewers'] as List).length;

    // ఒకవేళ పాత డేటాలో డైరెక్ట్ గా నెంబర్ ఉంటే..
    if (count == 0) {
      if (data['views'] != null)
        count = int.tryParse(data['views'].toString()) ?? 0;
      else if (data['viewCount'] != null)
        count = int.tryParse(data['viewCount'].toString()) ?? 0;
      else if (data['viewsCount'] != null)
        count = int.tryParse(data['viewsCount'].toString()) ?? 0;
    }

    // అసలు వ్యూస్ లేకపోతే అప్పుడు లైక్స్ తీసుకుంటుంది
    if (count == 0) {
      count = (data['likes'] as List?)?.length ?? 0;
    }

    return count;
  }

  Map<String, dynamic> _getRankDetails(int points) {
    if (points >= 500)
      return {
        "name": "Banjara Legend 👑",
        "color": Colors.amber,
        "next": 500,
        "msg": "You are a true community legend!",
      };
    if (points >= 100)
      return {
        "name": "Banjara Warrior ⚔️",
        "color": Colors.orangeAccent,
        "next": 500,
        "msg": "Keep inspiring the community!",
      };
    if (points >= 30)
      return {
        "name": "Rising Banjara 🌟",
        "color": Colors.blueAccent,
        "next": 100,
        "msg": "You are growing fast!",
      };
    return {
      "name": "Banjara Explorer 🏕️",
      "color": Colors.green[500]!,
      "next": 30,
      "msg": "Your journey just began!",
    };
  }

  void _showBadgeInfoDialog(int points, bool isDark) {
    var rank = _getRankDetails(points);
    double progress = points >= 500 ? 1.0 : (points / rank['next']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Center(
          child: Text(
            "🏆 Banjara Badge & Rank",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              size: 60,
              color: Colors.amber,
            ),
            const SizedBox(height: 10),
            Text(
              "Current Stage",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            Text(
              rank['name'],
              style: TextStyle(
                color: rank['color'],
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              rank['msg'],
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (points < 500) ...[
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                color: rank['color'],
                minHeight: 8,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(height: 5),
              Text(
                "$points / ${rank['next']} Points to next rank",
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
            const Divider(height: 30),
            const Text(
              "💡 How to earn points?",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.add_a_photo, size: 16, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text("2 Points for every Post / Reel"),
              ],
            ),
            const SizedBox(height: 5),
            const Row(
              children: [
                Icon(Icons.person_add, size: 16, color: Colors.green),
                SizedBox(width: 8),
                Text("1 Point for every Follower"),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Awesome! 🚀",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanjaraBadge(int totalPoints, bool isDark) {
    var rank = _getRankDetails(totalPoints);
    return GestureDetector(
      onTap: () => _showBadgeInfoDialog(totalPoints, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: (rank['color'] as Color).withAlpha(35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (rank['color'] as Color).withAlpha(100),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.military_tech_rounded, color: rank['color'], size: 20),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Banjara Badge",
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 9,
                    ),
                  ),
                  Text(
                    rank['name'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyTreeSection(bool isMe, bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FamilyTreeScreen(userId: targetUid),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade600, Colors.teal.shade500],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withAlpha(40),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.park_rounded, color: Colors.white, size: 20),
            SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "వంశవృక్షం",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                  ),
                  Text(
                    "Family Network",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white70, fontSize: 9.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playHighlightStories(List<dynamic> mediaUrls) {
    if (mediaUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No media in this highlight! 🏜️")),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HighlightViewerScreen(mediaUrls: mediaUrls),
      ),
    );
  }

  void _showDeleteHighlightDialog(String highlightId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Highlight? 🗑️',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Text(
          'Are you sure you want to permanently delete this highlight?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance
                    .collection('highlights')
                    .doc(highlightId)
                    .delete();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Highlight deleted! 🎉"),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Error: $e"),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightsSection(bool isMe, bool isDark) {
    return Container(
      height: 85,
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('highlights')
            .where(
              Filter.or(
                Filter('uid', isEqualTo: targetUid),
                Filter('ownerId', isEqualTo: targetUid),
              ),
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();
          var highlights = snapshot.data!.docs;
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: isMe ? highlights.length + 1 : highlights.length,
            itemBuilder: (context, index) {
              if (index == 0 && isMe) {
                return _buildHighlightCircle(
                  true,
                  "New",
                  isDark,
                  null,
                  [],
                  null,
                );
              }
              var highlightDoc = highlights[isMe ? index - 1 : index];
              var highlightData = highlightDoc.data() as Map<String, dynamic>;
              return _buildHighlightCircle(
                false,
                highlightData['name'] ?? '',
                isDark,
                highlightData['coverUrl'] ?? '',
                highlightData['mediaUrls'] ?? [],
                highlightDoc.id,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHighlightCircle(
    bool isAdd,
    String title,
    bool isDark,
    String? imgUrl,
    List<dynamic> mediaUrls,
    String? highlightId,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: GestureDetector(
        onTap: () {
          if (isAdd) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => const AddHighlightSheet(),
            );
          } else {
            _playHighlightStories(mediaUrls);
          }
        },
        onLongPress: () {
          if (!isAdd && highlightId != null && targetUid == currentUid) {
            _showDeleteHighlightDialog(highlightId);
          }
        },
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[400]!, width: 1),
                color: isDark ? Colors.grey[900] : Colors.grey[200],
              ),
              child: isAdd
                  ? Icon(Icons.add, color: isDark ? Colors.white : Colors.black)
                  : ClipOval(
                      child: imgUrl != null && imgUrl.isNotEmpty
                          ? Image.network(imgUrl, fit: BoxFit.cover)
                          : const Icon(Icons.image, color: Colors.grey),
                    ),
            ),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  void _showDeleteReelDialog(String reelId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Reel? 🗑️',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Text(
          'Are you sure you want to permanently delete this reel video?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              String res = await FirestoreMethods().deleteReel(reelId);
              if (!mounted) return;
              if (res == "success") {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Reel deleted! 🎉"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    bool isMe = targetUid == currentUid;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(targetUid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Text('Profile');
            var uData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            bool isPrivate = uData['isPrivate'] ?? false;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPrivate) const Icon(Icons.lock_outline_rounded, size: 18),
                if (isPrivate) const SizedBox(width: 5),
                Text(
                  uData['username'] ?? 'Profile',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          if (isMe)
            IconButton(
              icon: Icon(Icons.menu_rounded, color: textColor, size: 28),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                if (result == 'saved') _tabController.animateTo(2);
              },
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(targetUid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!userSnapshot.hasData || !userSnapshot.data!.exists)
            return const Center(child: Text('User not found.'));

          var userData =
              userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          String username = userData['username'] ?? 'User';
          String profilePic = userData['profilePic'] ?? '';
          String bio = userData['bio'] ?? 'No bio yet.';
          List followers = userData['followers'] ?? [];
          List following = userData['following'] ?? [];
          bool isFollowing = followers.contains(currentUid);
          bool isPrivate = userData['isPrivate'] ?? false;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where(
                  Filter.or(
                    Filter('uid', isEqualTo: targetUid),
                    Filter('ownerId', isEqualTo: targetUid),
                  ),
                )
                .snapshots(),
            builder: (context, postsSnapshot) {
              // 🌟 THE FIX 1: Posts లోంచి కేవలం ఫోటోలు/ఆడియోలు మాత్రమే ఫిల్టర్ చేస్తున్నాం
              var allPostsDocs = postsSnapshot.hasData
                  ? postsSnapshot.data!.docs
                  : <DocumentSnapshot>[];

              var purePostsDocs = allPostsDocs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                bool isReel =
                    data['isReel'] == true ||
                    data['type'] == 'video' ||
                    data['type'] == 'reel' ||
                    data.containsKey('videoUrl');
                return !isReel; // వీడియోలు కానివి మాత్రమే (Images, Audio)
              }).toList();

              int totalPoints =
                  (allPostsDocs.length * 2) +
                  followers.length; // పాయింట్స్ క్యాలిక్యులేషన్ పాతదే ఉంచాం

              return NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('stories')
                                      .where(
                                        Filter.or(
                                          Filter('uid', isEqualTo: targetUid),
                                          Filter(
                                            'ownerId',
                                            isEqualTo: targetUid,
                                          ),
                                        ),
                                      )
                                      .snapshots(),
                                  builder: (context, storySnap) {
                                    List<Map<String, dynamic>> activeStories =
                                        [];
                                    if (storySnap.hasData) {
                                      final DateTime twentyFourHoursAgo =
                                          DateTime.now().subtract(
                                            const Duration(hours: 24),
                                          );
                                      for (var doc in storySnap.data!.docs) {
                                        var data =
                                            doc.data() as Map<String, dynamic>;
                                        if (data['timestamp'] != null) {
                                          DateTime storyTime =
                                              (data['timestamp'] as Timestamp)
                                                  .toDate();
                                          if (storyTime.isAfter(
                                            twentyFourHoursAgo,
                                          )) {
                                            data['storyId'] = doc.id;
                                            activeStories.add(data);
                                          }
                                        }
                                      }
                                      activeStories.sort(
                                        (a, b) => (a['timestamp'] as Timestamp)
                                            .compareTo(
                                              b['timestamp'] as Timestamp,
                                            ),
                                      );
                                    }

                                    bool hasStory = activeStories.isNotEmpty;
                                    bool allSeen = activeStories.every(
                                      (story) => (story['viewers'] ?? [])
                                          .contains(currentUid),
                                    );

                                    return GestureDetector(
                                      onTap: () async {
                                        if (hasStory) {
                                          for (var story in activeStories) {
                                            if (!(story['viewers'] ?? [])
                                                .contains(currentUid)) {
                                              await FirebaseFirestore.instance
                                                  .collection('stories')
                                                  .doc(story['storyId'])
                                                  .update({
                                                    'viewers':
                                                        FieldValue.arrayUnion([
                                                          currentUid,
                                                        ]),
                                                  });
                                            }
                                          }
                                          if (context.mounted) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => StoryViewScreen(
                                                  userStories: activeStories,
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(3.5),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: hasStory
                                              ? (!allSeen
                                                    ? const LinearGradient(
                                                        colors: [
                                                          Colors.pink,
                                                          Colors.redAccent,
                                                          Colors.orange,
                                                        ],
                                                      )
                                                    : LinearGradient(
                                                        colors: [
                                                          Colors.grey[400]!,
                                                          Colors.grey[400]!,
                                                        ],
                                                      ))
                                              : null,
                                        ),
                                        child: CircleAvatar(
                                          radius: 38.5,
                                          backgroundColor: isDark
                                              ? Colors.black
                                              : Colors.white,
                                          child: CircleAvatar(
                                            radius: 36,
                                            backgroundImage:
                                                CachedNetworkImageProvider(
                                                  profilePic.isNotEmpty
                                                      ? profilePic
                                                      : 'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                                                ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildStatColumn(
                                        'Posts',
                                        purePostsDocs.length.toString(),
                                        textColor,
                                        null,
                                      ),
                                      _buildStatColumn(
                                        'Followers',
                                        followers.length.toString(),
                                        textColor,
                                        () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => FollowListScreen(
                                              uidsList: followers,
                                              titleType: "Followers",
                                            ),
                                          ),
                                        ),
                                      ),
                                      _buildStatColumn(
                                        'Following',
                                        following.length.toString(),
                                        textColor,
                                        () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => FollowListScreen(
                                              uidsList: following,
                                              titleType: "Following",
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  username,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: textColor,
                                  ),
                                ),
                                if (userData['isVerified'] == true ||
                                    totalPoints >= 500)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 5),
                                    child: Icon(
                                      Icons.verified,
                                      color: Colors.blueAccent,
                                      size: 18,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bio,
                                  maxLines: _isBioExpanded ? null : 2,
                                  overflow: _isBioExpanded
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                    fontSize: 14,
                                  ),
                                ),
                                if (bio.length > 50 && !_isBioExpanded)
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _isBioExpanded = true),
                                    child: const Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: Text(
                                        "more",
                                        style: TextStyle(
                                          color: Colors.blueAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildBanjaraBadge(
                                    totalPoints,
                                    isDark,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildFamilyTreeSection(isMe, isDark),
                                ),
                              ],
                            ),
                            _buildHighlightsSection(isMe, isDark),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 38,
                              child: isMe
                                  ? ElevatedButton(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => EditProfileScreen(
                                            userData: userData,
                                          ),
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDark
                                            ? Colors.grey[900]
                                            : Colors.grey[200],
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Edit Profile',
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () =>
                                                FirestoreMethods().followUser(
                                                  currentUid,
                                                  targetUid,
                                                ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isFollowing
                                                  ? (isDark
                                                        ? Colors.grey[900]
                                                        : Colors.grey[200])
                                                  : Colors.blueAccent,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Text(
                                              isFollowing
                                                  ? 'Following'
                                                  : 'Follow',
                                              style: TextStyle(
                                                color: isFollowing
                                                    ? textColor
                                                    : Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => ChatRoomScreen(
                                                  receiverUid: targetUid,
                                                  receiverUsername: username,
                                                ),
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isDark
                                                  ? Colors.grey[900]
                                                  : Colors.grey[200],
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Text(
                                              'Message',
                                              style: TextStyle(
                                                color: textColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 15),
                          ],
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverAppBarDelegate(
                        TabBar(
                          controller: _tabController,
                          indicatorColor: textColor,
                          labelColor: textColor,
                          unselectedLabelColor: Colors.grey,
                          tabs: const [
                            Tab(icon: Icon(Icons.grid_on_rounded)),
                            Tab(icon: Icon(Icons.movie_creation_outlined)),
                            Tab(icon: Icon(Icons.bookmark_border_rounded)),
                          ],
                        ),
                        isDark ? Colors.black : Colors.white,
                      ),
                    ),
                  ];
                },
                body: (!isMe && isPrivate && !isFollowing)
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.lock_outline_rounded,
                              size: 60,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'This Account is Private',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Follow to see their photos and videos.',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          // 🌟 TAB 1: POSTS (ఇక్కడ ప్యూర్ ఫోటోలు/ఆడియోలు మాత్రమే వస్తాయి)
                          purePostsDocs.isEmpty
                              ? const Center(
                                  child: Text(
                                    "No Posts Yet 📸",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : GridView.builder(
                                  padding: const EdgeInsets.all(2),
                                  itemCount: purePostsDocs.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        crossAxisSpacing: 2,
                                        mainAxisSpacing: 2,
                                      ),
                                  itemBuilder: (context, index) {
                                    var data =
                                        purePostsDocs[index].data()
                                            as Map<String, dynamic>;

                                    String type = data['type'] ?? 'image';
                                    String postUrl = '';
                                    List mediaList =
                                        data['postUrls'] ??
                                        data['postData'] ??
                                        [];
                                    if (mediaList.isNotEmpty) {
                                      postUrl = mediaList[0];
                                    } else {
                                      postUrl = data['postUrl'] ?? '';
                                    }

                                    bool isAudio =
                                        type == 'audio' ||
                                        postUrl.contains('.mp3') ||
                                        postUrl.contains('.m4a');

                                    // 🌟 THE FIX 2: పక్కాగా వ్యూస్ లాగే ఫంక్షన్ కాల్ చేస్తున్నాం
                                    int viewsCount = _getViewsCount(data);

                                    return GestureDetector(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ScrollableFeedScreen(
                                            docs: purePostsDocs,
                                            initialIndex: index,
                                            title: 'Posts',
                                            isReel: false,
                                          ),
                                        ),
                                      ),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          isAudio
                                              ? Container(
                                                  color: Colors.grey[850],
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.music_note,
                                                      color: Colors.white,
                                                      size: 40,
                                                    ),
                                                  ),
                                                )
                                              : (postUrl.isNotEmpty
                                                    ? Image.network(
                                                        postUrl,
                                                        fit: BoxFit.cover,
                                                        errorBuilder:
                                                            (
                                                              c,
                                                              e,
                                                              s,
                                                            ) => const Icon(
                                                              Icons
                                                                  .broken_image,
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                      )
                                                    : const Icon(
                                                        Icons.image,
                                                        color: Colors.grey,
                                                      )),
                                          if (!isAudio && mediaList.length > 1)
                                            const Positioned(
                                              top: 4,
                                              right: 4,
                                              child: Icon(
                                                Icons.file_copy,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          Positioned(
                                            bottom: 5,
                                            left: 5,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withAlpha(
                                                  150,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.remove_red_eye,
                                                    color: Colors.white,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "$viewsCount",
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),

                          // 🌟 TAB 2: REELS (ఇందులో పాత పోస్ట్‌లలో దాక్కున్న వీడియోలు + కొత్త రీల్స్ వస్తాయి)
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('reels')
                                .where(
                                  Filter.or(
                                    Filter('uid', isEqualTo: targetUid),
                                    Filter('ownerId', isEqualTo: targetUid),
                                  ),
                                )
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || !postsSnapshot.hasData)
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );

                              List<DocumentSnapshot> allReelsDocs = [
                                ...snapshot.data!.docs,
                              ];

                              // పాత పోస్ట్‌లలో ఉన్న వీడియోలను లాగి దీనికి కలుపుతున్నాం
                              var oldReelsDocs = allPostsDocs.where((doc) {
                                var data = doc.data() as Map<String, dynamic>;
                                return data['isReel'] == true ||
                                    data['type'] == 'video' ||
                                    data['type'] == 'reel' ||
                                    data.containsKey('videoUrl');
                              }).toList();

                              allReelsDocs.addAll(oldReelsDocs);

                              // టైమ్ బట్టి సార్ట్ చేస్తున్నాం
                              allReelsDocs.sort((a, b) {
                                var aData = a.data() as Map<String, dynamic>;
                                var bData = b.data() as Map<String, dynamic>;
                                var aTime =
                                    aData['timestamp'] ??
                                    aData['datePublished'];
                                var bTime =
                                    bData['timestamp'] ??
                                    bData['datePublished'];
                                if (aTime == null || bTime == null) return 0;
                                return (bTime as Timestamp).compareTo(
                                  aTime as Timestamp,
                                );
                              });

                              if (allReelsDocs.isEmpty)
                                return const Center(
                                  child: Text(
                                    'No Reels Yet 🎬',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                );

                              return GridView.builder(
                                padding: const EdgeInsets.all(2),
                                itemCount: allReelsDocs.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 2,
                                      mainAxisSpacing: 2,
                                      childAspectRatio: 0.7,
                                    ),
                                itemBuilder: (context, index) {
                                  var reelDoc = allReelsDocs[index];
                                  var reelData =
                                      reelDoc.data() as Map<String, dynamic>;

                                  String thumbUrl =
                                      reelData['thumbnailUrl'] ??
                                      reelData['coverUrl'] ??
                                      '';

                                  // 🌟 THE FIX 2: పక్కాగా వ్యూస్ లాగే ఫంక్షన్ కాల్ చేస్తున్నాం
                                  int viewsCount = _getViewsCount(reelData);

                                  return GestureDetector(
                                    onLongPress: isMe
                                        ? () =>
                                              _showDeleteReelDialog(reelDoc.id)
                                        : null,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ScrollableFeedScreen(
                                          docs: allReelsDocs,
                                          initialIndex: index,
                                          title: 'Reels 🎬',
                                          isReel: true,
                                        ),
                                      ),
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Container(
                                          color: isDark
                                              ? Colors.grey[900]
                                              : Colors.grey[200],
                                          child: thumbUrl.isNotEmpty
                                              ? Image.network(
                                                  thumbUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (c, e, s) =>
                                                      const Center(
                                                        child: Icon(
                                                          Icons
                                                              .play_circle_outline,
                                                          color: Colors.white,
                                                          size: 32,
                                                        ),
                                                      ),
                                                )
                                              : const Center(
                                                  child: Icon(
                                                    Icons.play_circle_outline,
                                                    color: Colors.white,
                                                    size: 32,
                                                  ),
                                                ),
                                        ),
                                        const Positioned(
                                          top: 4,
                                          right: 4,
                                          child: Icon(
                                            Icons.play_arrow_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 5,
                                          left: 5,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withAlpha(
                                                150,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
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
                                  );
                                },
                              );
                            },
                          ),

                          // 🌟 TAB 3: SAVED POSTS
                          (!isMe)
                              ? const Center(
                                  child: Text(
                                    '🔒 Saved items are private',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('posts')
                                      .where(
                                        'savedBy',
                                        arrayContains: currentUid,
                                      )
                                      .snapshots(),
                                  builder: (context, postsSnap) {
                                    return StreamBuilder<QuerySnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('reels')
                                          .where(
                                            'savedBy',
                                            arrayContains: currentUid,
                                          )
                                          .snapshots(),
                                      builder: (context, reelsSnap) {
                                        if (!postsSnap.hasData ||
                                            !reelsSnap.hasData)
                                          return const Center(
                                            child: CircularProgressIndicator(),
                                          );

                                        var allSavedDocs = <DocumentSnapshot>[
                                          ...postsSnap.data!.docs,
                                          ...reelsSnap.data!.docs,
                                        ];
                                        if (allSavedDocs.isEmpty)
                                          return const Center(
                                            child: Text(
                                              'No Saved Collections Yet 📥',
                                              style: TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          );

                                        allSavedDocs.sort((a, b) {
                                          var aData =
                                              a.data() as Map<String, dynamic>;
                                          var bData =
                                              b.data() as Map<String, dynamic>;
                                          var aTime =
                                              aData['timestamp'] ??
                                              aData['datePublished'];
                                          var bTime =
                                              bData['timestamp'] ??
                                              bData['datePublished'];
                                          if (aTime == null || bTime == null)
                                            return 0;
                                          return (bTime as Timestamp).compareTo(
                                            aTime as Timestamp,
                                          );
                                        });

                                        return GridView.builder(
                                          padding: const EdgeInsets.all(2),
                                          itemCount: allSavedDocs.length,
                                          gridDelegate:
                                              const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 3,
                                                crossAxisSpacing: 2,
                                                mainAxisSpacing: 2,
                                              ),
                                          itemBuilder: (context, index) {
                                            var doc = allSavedDocs[index];
                                            var data =
                                                doc.data()
                                                    as Map<String, dynamic>;

                                            bool isReel =
                                                data.containsKey('videoUrl') ||
                                                data['type'] == 'video' ||
                                                data['type'] == 'reel' ||
                                                data['isReel'] == true;
                                            String type =
                                                data['type'] ?? 'image';

                                            String postUrl = '';
                                            List mediaList =
                                                data['postUrls'] ??
                                                data['postData'] ??
                                                [];
                                            if (mediaList.isNotEmpty) {
                                              postUrl = mediaList[0];
                                            } else {
                                              postUrl =
                                                  data['postUrl'] ??
                                                  data['videoUrl'] ??
                                                  '';
                                            }

                                            bool isAudio =
                                                type == 'audio' ||
                                                postUrl.contains('.mp3') ||
                                                postUrl.contains('.m4a');
                                            String thumbUrl =
                                                data['thumbnailUrl'] ??
                                                data['coverUrl'] ??
                                                '';

                                            // 🌟 THE FIX 2: వ్యూస్ కౌంట్ ఫంక్షన్ వాడుతున్నాం
                                            int viewsCount = _getViewsCount(
                                              data,
                                            );

                                            return GestureDetector(
                                              onTap: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      ScrollableFeedScreen(
                                                        docs: allSavedDocs,
                                                        initialIndex: index,
                                                        title:
                                                            'Saved Collection',
                                                      ),
                                                ),
                                              ),
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  isReel
                                                      ? (thumbUrl.isNotEmpty
                                                            ? Image.network(
                                                                thumbUrl,
                                                                fit: BoxFit
                                                                    .cover,
                                                                errorBuilder: (c, e, s) => Container(
                                                                  color: Colors
                                                                      .grey[900],
                                                                  child: const Center(
                                                                    child: Icon(
                                                                      Icons
                                                                          .play_circle_outline,
                                                                      color: Colors
                                                                          .white,
                                                                      size: 32,
                                                                    ),
                                                                  ),
                                                                ),
                                                              )
                                                            : Container(
                                                                color: Colors
                                                                    .grey[900],
                                                                child: const Center(
                                                                  child: Icon(
                                                                    Icons
                                                                        .play_circle_outline,
                                                                    color: Colors
                                                                        .white,
                                                                    size: 32,
                                                                  ),
                                                                ),
                                                              ))
                                                      : isAudio
                                                      ? Container(
                                                          color:
                                                              Colors.grey[850],
                                                          child: const Center(
                                                            child: Icon(
                                                              Icons.music_note,
                                                              color:
                                                                  Colors.white,
                                                              size: 40,
                                                            ),
                                                          ),
                                                        )
                                                      : (postUrl.isNotEmpty
                                                            ? Image.network(
                                                                postUrl,
                                                                fit: BoxFit
                                                                    .cover,
                                                                errorBuilder:
                                                                    (
                                                                      c,
                                                                      e,
                                                                      s,
                                                                    ) => const Icon(
                                                                      Icons
                                                                          .broken_image,
                                                                      color: Colors
                                                                          .grey,
                                                                    ),
                                                              )
                                                            : const Icon(
                                                                Icons.image,
                                                                color:
                                                                    Colors.grey,
                                                              )),
                                                  Positioned(
                                                    top: 4,
                                                    right: 4,
                                                    child: Icon(
                                                      isReel
                                                          ? Icons
                                                                .play_arrow_rounded
                                                          : Icons
                                                                .photo_library_rounded,
                                                      color: Colors.white,
                                                      size: 16,
                                                    ),
                                                  ),
                                                  Positioned(
                                                    bottom: 5,
                                                    left: 5,
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 5,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black
                                                            .withAlpha(150),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            isReel
                                                                ? Icons
                                                                      .play_arrow_rounded
                                                                : Icons
                                                                      .remove_red_eye,
                                                            color: Colors.white,
                                                            size: 14,
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            "$viewsCount",
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                        ],
                      ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatColumn(
    String label,
    String count,
    Color textColor,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color bgColor;
  _SliverAppBarDelegate(this._tabBar, this.bgColor);
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Container(color: bgColor, child: _tabBar);
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

class HighlightViewerScreen extends StatefulWidget {
  final List<dynamic> mediaUrls;
  const HighlightViewerScreen({super.key, required this.mediaUrls});
  @override
  State<HighlightViewerScreen> createState() => _HighlightViewerScreenState();
}

class _HighlightViewerScreenState extends State<HighlightViewerScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  VideoPlayerController? _videoController;
  bool _isVideo = false;

  @override
  void initState() {
    super.initState();
    _playMedia();
  }

  void _playMedia() {
    _videoController?.dispose();
    _videoController = null;
    _isVideo = false;
    String url = widget.mediaUrls[_currentIndex].toString();
    if (url.contains('.mp4') ||
        url.contains('story_videos') ||
        url.contains('reels') ||
        url.contains('video')) {
      _isVideo = true;
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _videoController!.play();
            _videoController!.addListener(() {
              if (_videoController!.value.position >=
                  _videoController!.value.duration) {
                _nextPage();
              }
            });
          }
        });
    }
  }

  void _nextPage() {
    if (_currentIndex < widget.mediaUrls.length - 1) {
      setState(() {
        _currentIndex++;
        _playMedia();
      });
      _pageController.jumpToPage(_currentIndex);
    } else {
      Navigator.pop(context);
    }
  }

  void _previousPage() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _playMedia();
      });
      _pageController.jumpToPage(_currentIndex);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            GestureDetector(
              onTapDown: (details) {
                double screenWidth = MediaQuery.of(context).size.width;
                if (details.globalPosition.dx < screenWidth / 3) {
                  _previousPage();
                } else {
                  _nextPage();
                }
              },
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.mediaUrls.length,
                itemBuilder: (context, index) {
                  if (_isVideo &&
                      _videoController != null &&
                      _videoController!.value.isInitialized) {
                    return Center(
                      child: AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      ),
                    );
                  }
                  return Image.network(
                    widget.mediaUrls[index],
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 20,
              right: 15,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              right: 60,
              child: Row(
                children: List.generate(
                  widget.mediaUrls.length,
                  (index) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 3,
                      decoration: BoxDecoration(
                        color: _currentIndex >= index
                            ? Colors.white
                            : Colors.white.withAlpha(76),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScrollableFeedScreen extends StatefulWidget {
  final List<DocumentSnapshot> docs;
  final int initialIndex;
  final String title;
  final bool isReel;
  const ScrollableFeedScreen({
    super.key,
    required this.docs,
    required this.initialIndex,
    required this.title,
    this.isReel = false,
  });
  @override
  State<ScrollableFeedScreen> createState() => _ScrollableFeedScreenState();
}

class _ScrollableFeedScreenState extends State<ScrollableFeedScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
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
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        title: Text(
          widget.title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _pageController,
        itemCount: widget.docs.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          var doc = widget.docs[index];
          var data = doc.data() as Map<String, dynamic>;
          bool isReelItem =
              widget.isReel ||
              data.containsKey('videoUrl') ||
              data['type'] == 'video' ||
              data['type'] == 'reel' ||
              data['isReel'] == true;
          if (isReelItem) {
            return Container(
              color: Colors.black,
              child: HomeReelCard(
                reelData: data,
                reelId: doc.id,
                isActive: _currentIndex == index,
              ),
            );
          } else {
            return HomePostCard(
              postData: data,
              postId: doc.id,
              isActive: _currentIndex == index,
            );
          }
        },
      ),
    );
  }
}
