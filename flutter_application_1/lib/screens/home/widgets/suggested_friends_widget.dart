// lib/screens/home/widgets/suggested_friends_widget.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 🌟 THE FIX
import '../../profile/profile_screen.dart';

class SuggestedFriendsWidget extends StatelessWidget {
  final bool isDark;
  const SuggestedFriendsWidget({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: isDark ? Colors.grey[900] : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Suggested for you",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AllSuggestedFriendsScreen(currentUid: currentUid),
                    ),
                  ),
                  child: const Text(
                    "See All",
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 220,
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUid)
                  .snapshots(),
              builder: (context, mySnap) {
                if (!mySnap.hasData) return const SizedBox();
                var myData = mySnap.data!.data() as Map<String, dynamic>? ?? {};
                List myFollowing = myData['following'] ?? [];

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .limit(20)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());

                    var users = snapshot.data!.docs
                        .where(
                          (doc) =>
                              doc.id != currentUid &&
                              !myFollowing.contains(doc.id),
                        )
                        .toList();
                    if (users.isEmpty) return const SizedBox();

                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
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

                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(userId: targetUid),
                            ),
                          ),
                          child: Container(
                            width: 140,
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[850] : Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.grey.withAlpha(50),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(10),
                                  blurRadius: 5,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 35,
                                  // 🌟 THE FIX
                                  backgroundImage: CachedNetworkImageProvider(
                                    userData['profilePic'] ??
                                        'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  userData['username'] ?? 'User',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  mutualCount > 0
                                      ? "$mutualCount mutual friends"
                                      : "Suggested for you",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                                const Spacer(),
                                SizedBox(
                                  width: double.infinity,
                                  height: 32,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueAccent,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () async {
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
                                    },
                                    child: const Text(
                                      "Follow",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
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
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AllSuggestedFriendsScreen extends StatefulWidget {
  final String currentUid;
  const AllSuggestedFriendsScreen({super.key, required this.currentUid});
  @override
  State<AllSuggestedFriendsScreen> createState() =>
      _AllSuggestedFriendsScreenState();
}

class _AllSuggestedFriendsScreenState extends State<AllSuggestedFriendsScreen> {
  final Set<String> _hiddenUsers = {};
  String _searchQuery = "";
  List _myFollowing = [];

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUid)
        .get()
        .then((doc) {
          if (doc.exists && mounted)
            setState(() => _myFollowing = doc.data()?['following'] ?? []);
        });
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = isDark ? const Color(0xFF0E0E0E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
        title: Text(
          "Discover people",
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: TextField(
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase().trim()),
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: "Search users...",
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: isDark ? Colors.grey[900] : Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                var filteredUsers = snapshot.data!.docs.where((doc) {
                  if (doc.id == widget.currentUid ||
                      _hiddenUsers.contains(doc.id) ||
                      _myFollowing.contains(doc.id))
                    return false;
                  String username =
                      ((doc.data() as Map<String, dynamic>)['username'] ?? "")
                          .toString()
                          .toLowerCase();
                  if (_searchQuery.isNotEmpty &&
                      !username.contains(_searchQuery))
                    return false;
                  return true;
                }).toList();

                if (filteredUsers.isEmpty)
                  return const Center(
                    child: Text(
                      "No users found",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );

                return ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(15, 20, 15, 10),
                      child: Text(
                        "Suggested for you",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                    ),
                    ...filteredUsers.map((doc) {
                      var userData = doc.data() as Map<String, dynamic>;
                      String targetUid = doc.id;
                      List targetFollowers = userData['followers'] ?? [];
                      int mutualCount = _myFollowing
                          .where((id) => targetFollowers.contains(id))
                          .length;
                      String subtitle = mutualCount > 0
                          ? "$mutualCount mutual friends"
                          : "Suggested for you";

                      return ListTile(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(userId: targetUid),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          radius: 26,
                          // 🌟 THE FIX
                          backgroundImage: CachedNetworkImageProvider(
                            userData['profilePic'] ??
                                'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                          ),
                        ),
                        title: Text(
                          userData['username'] ?? 'User',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 32,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4C68FF),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(widget.currentUid)
                                      .update({
                                        'following': FieldValue.arrayUnion([
                                          targetUid,
                                        ]),
                                      });
                                  FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(targetUid)
                                      .update({
                                        'followers': FieldValue.arrayUnion([
                                          widget.currentUid,
                                        ]),
                                      });
                                  setState(() => _hiddenUsers.add(targetUid));
                                },
                                child: const Text(
                                  "Follow",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _hiddenUsers.add(targetUid)),
                              child: Padding(
                                padding: const EdgeInsets.all(5.0),
                                child: Icon(
                                  Icons.close,
                                  color: textColor,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
