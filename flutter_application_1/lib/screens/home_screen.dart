// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use, unused_import

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/safe_elements.dart';
import '../widgets/post_widget.dart';
import 'story_screen.dart';
import 'add_post_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  // 🌟 Pull to Refresh కోసం ఫంక్షన్
  Future<void> _refreshFeed() async {
    // ఫైర్‌బేస్ ఆటోమేటిక్ గా రియల్-టైమ్ అప్‌డేట్ అవుతుంది, కాబట్టి జస్ట్ చిన్న డిలే ఇస్తున్నాం స్మూత్ ఫీల్ కోసం
    await Future.delayed(const Duration(seconds: 1));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFD1D1D),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddPostScreen()),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          var userData =
              userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          List feedUserIds = List.from(userData['following'] ?? [])
            ..add(currentUid);
          DateTime yesterday = DateTime.now().subtract(
            const Duration(hours: 24),
          );

          return RefreshIndicator(
            // 🌟 Pull to Refresh ఇక్కడే యాడ్ చేశాం!
            onRefresh: _refreshFeed,
            color: const Color(0xFFFD1D1D),
            child: CustomScrollView(
              physics:
                  const AlwaysScrollableScrollPhysics(), // కిందకి లాగడానికి
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // 🌟 స్టోరీస్ సెక్షన్
                      SizedBox(
                        height: 110,
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('stories')
                              .where(
                                'timestamp',
                                isGreaterThanOrEqualTo: yesterday,
                              )
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const SizedBox();

                            var validStories = snapshot.data!.docs.toList();
                            Map<String, Map<String, dynamic>> uniqueStoryUsers =
                                {};
                            for (var doc in validStories) {
                              var data = doc.data() as Map<String, dynamic>;
                              data['storyId'] = doc.id;
                              uniqueStoryUsers[data['ownerId']] = data;
                            }
                            var storyList = uniqueStoryUsers.values.toList();

                            return ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: storyList.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      children: [
                                        Stack(
                                          alignment: Alignment.bottomRight,
                                          children: [
                                            SafeProfilePic(
                                              base64String:
                                                  userData['profilePic'],
                                              radius: 32,
                                              fallbackText:
                                                  userData['username'] != null
                                                  ? userData['username'][0]
                                                  : "U",
                                            ),
                                            Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.black
                                                    : Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Container(
                                                decoration: const BoxDecoration(
                                                  color: Colors.blue,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.add,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        AutoScrollText(
                                          text: "Your Story",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                var userStory = storyList[index - 1];
                                List viewers = userStory['viewers'] ?? [];
                                bool isSeen = viewers.contains(currentUid);

                                return GestureDetector(
                                  onTap: () async {
                                    await FirebaseFirestore.instance
                                        .collection('stories')
                                        .doc(userStory['storyId'])
                                        .update({
                                          'viewers': FieldValue.arrayUnion([
                                            currentUid,
                                          ]),
                                        });
                                    if (!context.mounted) return;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            StoryScreen(user: userStory),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: isSeen
                                                ? const LinearGradient(
                                                    colors: [
                                                      Colors.grey,
                                                      Colors.grey,
                                                    ],
                                                  )
                                                : const LinearGradient(
                                                    colors: [
                                                      Color(0xFF833AB4),
                                                      Color(0xFFFD1D1D),
                                                      Color(0xFFFCAF45),
                                                    ],
                                                  ),
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isDark
                                                  ? Colors.black
                                                  : Colors.white,
                                            ),
                                            child: SafeProfilePic(
                                              base64String:
                                                  userStory['profilePic'],
                                              radius: 28,
                                              fallbackText:
                                                  userStory['username'] != null
                                                  ? userStory['username'][0]
                                                  : "U",
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        AutoScrollText(
                                          text: userStory['username'] ?? "User",
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isSeen
                                                ? Colors.grey
                                                : (isDark
                                                      ? Colors.white
                                                      : Colors.black),
                                            fontWeight: isSeen
                                                ? FontWeight.normal
                                                : FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                  ),
                ),
                // 🌟 పోస్ట్ ఫీడ్ సెక్షన్
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      );

                    // 1. Privacy Logic (పబ్లిక్ అయితే అందరికీ, ప్రైవేట్ అయితే ఫాలోవర్స్ కి)
                    var validPosts = snapshot.data!.docs.where((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      bool isPublic = data['isPublic'] ?? true;
                      bool isFollowing = feedUserIds.contains(data['ownerId']);
                      return isPublic || isFollowing;
                    }).toList();

                    // 2. Seen / Unseen Logic
                    List<DocumentSnapshot> unseenPosts = [];
                    List<DocumentSnapshot> seenPosts = [];

                    for (var doc in validPosts) {
                      var data = doc.data() as Map<String, dynamic>;
                      List viewedBy = data['viewedBy'] ?? [];
                      if (viewedBy.contains(currentUid)) {
                        seenPosts.add(doc);
                      } else {
                        unseenPosts.add(doc);
                      }
                    }

                    // 3. చూడని పోస్ట్‌లను రాండమ్ గా మిక్స్ చేస్తున్నాం
                    unseenPosts.shuffle();

                    // 4. ముందు చూడనివి, ఆ తర్వాత చూసినవి (చూసినవి లేటెస్ట్ టైమ్ బట్టి)
                    var finalFeed = [...unseenPosts, ...seenPosts];

                    if (finalFeed.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(50.0),
                            child: Text("No posts yet!"),
                          ),
                        ),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        var post =
                            finalFeed[index].data() as Map<String, dynamic>;
                        post['postId'] = finalFeed[index].id;
                        return PostWidget(post: post);
                      }, childCount: finalFeed.length),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// 🌟 ఆటోమాటిక్ గా స్క్రోల్ అయ్యే మ్యాజిక్ విడ్జెట్
class AutoScrollText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const AutoScrollText({super.key, required this.text, required this.style});

  @override
  State<AutoScrollText> createState() => _AutoScrollTextState();
}

class _AutoScrollTextState extends State<AutoScrollText> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _startScrolling();
  }

  void _startScrolling() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    while (mounted) {
      if (_scrollController.hasClients) {
        double maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll > 0) {
          await _scrollController.animateTo(
            maxScroll,
            duration: const Duration(seconds: 2),
            curve: Curves.linear,
          );
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) break;
          await _scrollController.animateTo(
            0,
            duration: const Duration(seconds: 2),
            curve: Curves.linear,
          );
          await Future.delayed(const Duration(seconds: 1));
        } else {
          await Future.delayed(const Duration(seconds: 2));
        }
      } else {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: Text(widget.text, style: widget.style),
      ),
    );
  }
}
