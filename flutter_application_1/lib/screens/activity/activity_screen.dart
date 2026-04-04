// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';

import '../../widgets/safe_elements.dart';
import '../posts/scrolling_posts_screen.dart';
import '../reels/scrolling_reels_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    // 🌟 స్క్రీన్ ఓపెన్ చేయగానే అన్-రీడ్ నోటిఫికేషన్స్ అన్నీ "రీడ్" అవుతాయి
    _markNotificationsAsRead();
  }

  // 🌟 బ్యాడ్జ్ కౌంట్ క్లియర్ చేయడానికి మ్యాజిక్ లాజిక్
  Future<void> _markNotificationsAsRead() async {
    try {
      var unreadDocs = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadDocs.docs.isNotEmpty) {
        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (var doc in unreadDocs.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint("Mark as read error: $e");
    }
  }

  // ====================================================================
  // 🌟 1. జనరల్ నోటిఫికేషన్స్ యాక్షన్స్ (Likes, Comments)
  // ====================================================================
  Future<void> _deleteGeneralNotification(String notifId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('notifications')
          .doc(notifId)
          .delete();
    } catch (e) {
      debugPrint("Delete Notification Error: $e");
    }
  }

  Future<void> _clearAllGeneralNotifications() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear All Activity?"),
        content: const Text(
          "This will delete all your likes and comments notifications.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Clear All",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      var snapshots = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('notifications')
          .get();
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshots.docs) batch.delete(doc.reference);
      await batch.commit();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All notifications cleared! 🧹")),
        );
    }
  }

  // ====================================================================
  // 🌟 2. టాగ్స్ అండ్ మెన్షన్స్ యాక్షన్స్ (Tags)
  // ====================================================================

  // స్వైప్ చేస్తే కేవలం నోటిఫికేషన్ మాత్రమే హైడ్ అవ్వాలి
  Future<void> _hideTagNotification(String postId) async {
    try {
      await FirebaseFirestore.instance.collection('posts').doc(postId).set({
        'hiddenTags': FieldValue.arrayUnion([currentUid]),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Hide Tag Notification Error: $e");
    }
  }

  // పోస్ట్ లోంచి మన పేరు పర్మనెంట్ గా తీసేయడం (Untag Me)
  Future<void> _removeTagFromPost(String postId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Tag?"),
        content: const Text(
          "You will be removed from this post and it won't appear on your profile. Are you sure?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Remove Me",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'taggedUsers': FieldValue.arrayRemove([currentUid]),
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tag removed successfully! 🚫")),
        );
    }
  }

  Future<void> _clearAllTagNotifications(List<String> visiblePostIds) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear Tag Notifications?"),
        content: const Text(
          "This will clear these notifications, but you will still remain tagged in the posts.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Clear All",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (String pid in visiblePostIds) {
        batch.set(
          FirebaseFirestore.instance.collection('posts').doc(pid),
          {
            'hiddenTags': FieldValue.arrayUnion([currentUid]),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tag notifications cleared! 🧹")),
        );
    }
  }

  // ====================================================================
  // 🌟 మెయిన్ డిజైన్ (UI)
  // ====================================================================
  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        appBar: AppBar(
          backgroundColor: isDark ? Colors.black : Colors.white,
          title: const Text(
            "Notifications",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            indicatorColor: Color(0xFFFD1D1D),
            labelColor: Color(0xFFFD1D1D),
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: "All Activity"),
              Tab(text: "Tags & Mentions"),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildGeneralNotifications(), _buildTagsSection()],
        ),
      ),
    );
  }

  // 🌟 ట్యాబ్ 1: All Activity
  Widget _buildGeneralNotifications() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('notifications')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text("Error loading activity"));
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        var notifications = snapshot.data!.docs.toList();
        notifications.sort((a, b) {
          Timestamp? t1 = (a.data() as Map)['timestamp'] as Timestamp?;
          Timestamp? t2 = (b.data() as Map)['timestamp'] as Timestamp?;
          if (t1 == null && t2 == null) return 0;
          if (t1 == null) return 1;
          if (t2 == null) return -1;
          return t2.compareTo(t1);
        });

        if (notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 10),
                const Text(
                  "No Activity Yet",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                const Text(
                  "When someone likes or comments on\nyour posts, it will appear here.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Recent",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  TextButton(
                    onPressed: _clearAllGeneralNotifications,
                    child: const Text(
                      "Clear All",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  var data =
                      notifications[index].data() as Map<String, dynamic>;
                  String notifId = notifications[index].id;

                  String type = data['type'] ?? '';
                  String senderName = data['senderName'] ?? 'User';
                  String senderPic = data['senderPic'] ?? '';
                  String postId = data['postId'] ?? '';
                  String mediaUrl = data['mediaUrl'] ?? '';
                  String commentText = data['text'] ?? '';
                  DateTime time =
                      (data['timestamp'] as Timestamp?)?.toDate() ??
                      DateTime.now();

                  String actionText = "";
                  if (type == 'like')
                    actionText = " liked your post. ❤️";
                  else if (type == 'comment')
                    actionText = " commented: $commentText 💬";
                  else if (type == 'follow')
                    actionText = " started following you. 👤";
                  else
                    actionText = " interacted with your post.";

                  return Dismissible(
                    key: Key(notifId),
                    direction: DismissDirection.endToStart,
                    onDismissed: (direction) =>
                        _deleteGeneralNotification(notifId),
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        if (postId.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ScrollingPostsScreen(
                                postIds: [postId],
                                initialIndex: 0,
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 12,
                        ),
                        color: isDark ? Colors.black : Colors.white,
                        child: Row(
                          children: [
                            SafeProfilePic(
                              base64String: senderPic,
                              radius: 22,
                              fallbackText: senderName.isNotEmpty
                                  ? senderName[0].toUpperCase()
                                  : 'U',
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                        fontSize: 14,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: senderName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        TextSpan(text: actionText),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timeago.format(time, locale: 'en_short'),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (mediaUrl.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: CachedNetworkImage(
                                  imageUrl: mediaUrl,
                                  width: 45,
                                  height: 45,
                                  fit: BoxFit.cover,
                                  placeholder: (c, u) =>
                                      Container(color: Colors.grey.shade300),
                                  errorWidget: (c, u, e) => Container(
                                    color: Colors.grey.shade300,
                                    child: const Icon(
                                      Icons.broken_image,
                                      size: 20,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
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
  }

  // 🌟 ట్యాబ్ 2: Tags & Mentions
  Widget _buildTagsSection() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('taggedUsers', arrayContains: currentUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text("Unable to load tags."));
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        var taggedPosts = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          List hiddenTags = data['hiddenTags'] ?? [];
          return !hiddenTags.contains(currentUid);
        }).toList();

        taggedPosts.sort((a, b) {
          Timestamp? t1 = (a.data() as Map)['timestamp'] as Timestamp?;
          Timestamp? t2 = (b.data() as Map)['timestamp'] as Timestamp?;
          if (t1 == null && t2 == null) return 0;
          if (t1 == null) return 1;
          if (t2 == null) return -1;
          return t2.compareTo(t1);
        });

        if (taggedPosts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_pin_circle_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 10),
                const Text(
                  "No Tags Yet",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                const Text(
                  "When someone tags you in a post or reel,\nit will appear here.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        List<String> visiblePostIds = taggedPosts.map((e) => e.id).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Recent Tags",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  TextButton(
                    onPressed: () => _clearAllTagNotifications(visiblePostIds),
                    child: const Text(
                      "Clear All",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: taggedPosts.length,
                itemBuilder: (context, index) {
                  var postData =
                      taggedPosts[index].data() as Map<String, dynamic>;
                  String postId = taggedPosts[index].id;
                  String ownerName = postData['username'] ?? 'User';
                  String ownerPic = postData['profilePic'] ?? '';
                  String postType = postData['type'] ?? 'image';

                  String thumbnailUrl =
                      (postData['postData'] is List &&
                          (postData['postData'] as List).isNotEmpty)
                      ? postData['postData'][0].toString()
                      : (postData['storyUrl'] ?? "");

                  DateTime time =
                      (postData['timestamp'] as Timestamp?)?.toDate() ??
                      DateTime.now();

                  return Dismissible(
                    key: Key("tag_$postId"),
                    direction: DismissDirection.endToStart,
                    onDismissed: (direction) => _hideTagNotification(postId),
                    background: Container(
                      color: Colors.orange,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(
                        Icons.visibility_off,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        if (postType == 'video') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ScrollingReelsScreen(
                                reelIds: [postId],
                                initialIndex: 0,
                              ),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ScrollingPostsScreen(
                                postIds: [postId],
                                initialIndex: 0,
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.only(
                          left: 15,
                          right: 5,
                          top: 12,
                          bottom: 12,
                        ),
                        color: isDark ? Colors.black : Colors.white,
                        child: Row(
                          children: [
                            SafeProfilePic(
                              base64String: ownerPic,
                              radius: 22,
                              fallbackText: ownerName.isNotEmpty
                                  ? ownerName[0].toUpperCase()
                                  : 'U',
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                        fontSize: 14,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: ownerName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        TextSpan(
                                          text: postType == 'video'
                                              ? " tagged you in a reel."
                                              : " tagged you in a post.",
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timeago.format(time, locale: 'en_short'),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: CachedNetworkImage(
                                imageUrl: thumbnailUrl,
                                width: 45,
                                height: 45,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    Container(color: Colors.grey.shade300),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey.shade300,
                                  child: const Icon(
                                    Icons.broken_image,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert,
                                color: Colors.grey,
                              ),
                              onSelected: (value) {
                                if (value == 'remove_tag')
                                  _removeTagFromPost(postId);
                                if (value == 'hide_notif')
                                  _hideTagNotification(postId);
                              },
                              itemBuilder: (BuildContext context) => [
                                const PopupMenuItem(
                                  value: 'hide_notif',
                                  child: Text("Hide Notification"),
                                ),
                                const PopupMenuItem(
                                  value: 'remove_tag',
                                  child: Text(
                                    "Remove me from Post",
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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
  }
}
