// lib/screens/home/widgets/home_stories_bar.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 🌟 THE FIX
import '../story_view_screen.dart';
import 'add_story_bottom_sheet.dart';

class HomeStoriesBar extends StatelessWidget {
  final String myVillageName;
  final String myProfilePic;

  const HomeStoriesBar({
    super.key,
    required this.myVillageName,
    required this.myProfilePic,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String currentUid = FirebaseAuth.instance.currentUser!.uid;
    final DateTime twentyFourHoursAgo = DateTime.now().subtract(
      const Duration(hours: 24),
    );
    final navigator = Navigator.of(context);

    return Container(
      height: 115,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[900]! : Colors.grey[200]!,
            width: 0.5,
          ),
        ),
      ),
      child: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('stories').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(
              child: SizedBox(
                width: 30,
                child: LinearProgressIndicator(color: Colors.blueAccent),
              ),
            );

          List<QueryDocumentSnapshot<Map<String, dynamic>>> allStories =
              snapshot.data?.docs ?? [];
          List<QueryDocumentSnapshot<Map<String, dynamic>>> activeStories =
              allStories.where((doc) {
                var data = doc.data();
                if (data['timestamp'] == null) return true;
                DateTime storyTime = (data['timestamp'] as Timestamp).toDate();
                if (!storyTime.isAfter(twentyFourHoursAgo)) return false;
                String privacy = data['privacy'] ?? 'everyone';
                String storyVillage = data['village'] ?? '';
                String storyUid = data['uid'] ?? '';
                if (storyUid == currentUid) return true;
                if (privacy == 'village' &&
                    storyVillage.toLowerCase() != myVillageName.toLowerCase())
                  return false;
                return true;
              }).toList();

          activeStories.sort((a, b) {
            var aTime = a.data()['timestamp'] as Timestamp?;
            var bTime = b.data()['timestamp'] as Timestamp?;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return aTime.compareTo(bTime);
          });

          Map<String, List<Map<String, dynamic>>> groupedStories = {};
          for (var doc in activeStories) {
            String uid = doc.data()['uid'] ?? '';
            if (!groupedStories.containsKey(uid)) groupedStories[uid] = [];
            Map<String, dynamic> storyData = doc.data();
            storyData['storyId'] = doc.id;
            groupedStories[uid]!.add(storyData);
          }

          List<Map<String, dynamic>> myStoriesList =
              groupedStories[currentUid] ?? [];
          List<String> otherUserUids = groupedStories.keys
              .where((uid) => uid != currentUid)
              .toList();

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: 1 + otherUserUids.length,
            itemBuilder: (context, index) {
              if (index == 0) {
                bool hasActiveStory = myStoriesList.isNotEmpty;
                bool myStorySeen = false;
                if (hasActiveStory)
                  myStorySeen = myStoriesList.every(
                    (story) => (story['viewers'] ?? []).contains(currentUid),
                  );

                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (hasActiveStory)
                                navigator.push(
                                  MaterialPageRoute(
                                    builder: (_) => StoryViewScreen(
                                      userStories: myStoriesList,
                                    ),
                                  ),
                                );
                              else
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(20),
                                      topRight: Radius.circular(20),
                                    ),
                                  ),
                                  builder: (ctx) => AddStoryBottomSheet(
                                    myVillage: myVillageName,
                                  ),
                                );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: hasActiveStory
                                    ? (myStorySeen
                                          ? LinearGradient(
                                              colors: [
                                                Colors.grey[400]!,
                                                Colors.grey[600]!,
                                              ],
                                            )
                                          : const LinearGradient(
                                              colors: [
                                                Colors.pink,
                                                Colors.redAccent,
                                                Colors.orange,
                                              ],
                                            ))
                                    : LinearGradient(
                                        colors: [
                                          isDark
                                              ? Colors.grey[800]!
                                              : Colors.grey[300]!,
                                          isDark
                                              ? Colors.grey[800]!
                                              : Colors.grey[300]!,
                                        ],
                                      ),
                              ),
                              child: CircleAvatar(
                                radius: 29,
                                backgroundColor: isDark
                                    ? Colors.black
                                    : Colors.white,
                                child: CircleAvatar(
                                  radius: 26,
                                  // 🌟 THE FIX: Your Story Pic Cached
                                  backgroundImage: CachedNetworkImageProvider(
                                    myProfilePic.isNotEmpty
                                        ? myProfilePic
                                        : 'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20),
                                  ),
                                ),
                                builder: (ctx) => AddStoryBottomSheet(
                                  myVillage: myVillageName,
                                ),
                              ),
                              child: const CircleAvatar(
                                radius: 11,
                                backgroundColor: Colors.blueAccent,
                                child: Icon(
                                  Icons.add,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        hasActiveStory ? "Your Story" : "Add Story",
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }

              String otherUid = otherUserUids[index - 1];
              List<Map<String, dynamic>> userStoriesList =
                  groupedStories[otherUid] ?? [];
              var firstStory = userStoriesList.first;
              bool allSeen = userStoriesList.every(
                (story) => (story['viewers'] ?? []).contains(currentUid),
              );

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: GestureDetector(
                  onTap: () => navigator.push(
                    MaterialPageRoute(
                      builder: (_) =>
                          StoryViewScreen(userStories: userStoriesList),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: allSeen
                              ? LinearGradient(
                                  colors: [
                                    Colors.grey[400]!,
                                    Colors.grey[600]!,
                                  ],
                                )
                              : const LinearGradient(
                                  colors: [
                                    Colors.pink,
                                    Colors.redAccent,
                                    Colors.orange,
                                  ],
                                ),
                        ),
                        child: CircleAvatar(
                          radius: 29,
                          backgroundColor: isDark ? Colors.black : Colors.white,
                          child: CircleAvatar(
                            radius: 26,
                            // 🌟 THE FIX: Others Story Pic Cached
                            backgroundImage: CachedNetworkImageProvider(
                              firstStory['profilePic']
                                          ?.toString()
                                          .trim()
                                          .isNotEmpty ==
                                      true
                                  ? firstStory['profilePic'].toString()
                                  : 'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        firstStory['username'] ?? firstStory['name'] ?? 'User',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
