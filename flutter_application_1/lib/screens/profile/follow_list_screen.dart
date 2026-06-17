// lib/screens/profile/follow_list_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';
import '../../services/firestore_methods.dart';

class FollowListScreen extends StatelessWidget {
  final List<dynamic>
  uidsList; // 🌟 ఫాలోవర్స్ లేదా ఫాలోయింగ్ యూజర్ల ID ల లిస్ట్ బాస్!
  final String
  titleType; // 🌟 "Followers" లేదా "Following" అని తెలుపుతుంది బాస్!

  const FollowListScreen({
    super.key,
    required this.uidsList,
    required this.titleType,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          titleType, // 👥 ఫాలోవర్స్ లేదా ఫాలోయింగ్ టైటిల్ బాస్
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: textColor,
          ),
        ),
      ),
      body: uidsList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 60,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No $titleType Yet 🏜️',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: uidsList.length,
              itemBuilder: (context, index) {
                String targetUid = uidsList[index].toString();

                // 📡 🌟 ఫైర్‌స్టోర్ నుండి ప్రతి యూజర్ ప్రొఫైల్ వివరాలను లైవ్‌గా లోడ్ చేసే స్ట్రీమ్ బిల్డర్ బాస్!
                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(targetUid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const SizedBox.shrink(); // ఒకవేళ యూజర్ డేటా లేకపోతే ఖాళీగా ఉంచుతాం బాస్
                    }

                    var userData =
                        snapshot.data!.data() as Map<String, dynamic>;
                    String username = userData['username'] ?? 'User';
                    String profilePic = userData['profilePic'] ?? '';
                    String bio = userData['bio'] ?? 'Hey there!';
                    List followersList = userData['followers'] ?? [];
                    bool isFollowingTarget = followersList.contains(currentUid);
                    bool isMe = targetUid == currentUid;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      onTap: () {
                        // 🚀 క్లిక్ చేయగానే నేరుగా వారి ప్రొఫైల్ కి నావిగేట్ అవుతుంది బాస్!
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(userId: targetUid),
                          ),
                        );
                      },
                      // 🌟 ListView.builder లోపల ఉన్న ListTile లో:
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundImage: CachedNetworkImageProvider(
                          profilePic.isNotEmpty
                              ? profilePic
                              : 'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                        ),
                      ),
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            username,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              fontSize: 14.5,
                            ),
                          ),
                          // 🔵 బ్లూ వెరిఫైడ్ బ్యాడ్జ్ ఇక్కడ కూడా కిరాక్‌గా డిస్‌ప్లే అవుతుంది బాస్!
                          if (userData['isVerified'] == true) ...[
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.verified,
                              color: Colors.blueAccent,
                              size: 15,
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        bio,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12.5,
                        ),
                      ),
                      // 🤝 🎛️ లిస్ట్ లోనే డైరెక్ట్‌గా ఫాలో/అన్‌ఫాలో కొట్టే లగ్జరీ బటన్ బాస్!
                      trailing: isMe
                          ? null // మన పేరు పక్కన బటన్ ఉండదు బాస్
                          : SizedBox(
                              height: 32,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isFollowingTarget
                                      ? (isDark
                                            ? Colors.grey[900]
                                            : Colors.grey[200])
                                      : Colors.blueAccent,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () async {
                                  // ఫాలో/అన్‌ఫాలో టోగుల్ సర్వీస్ కాల్ బాస్
                                  await FirestoreMethods().followUser(
                                    currentUid,
                                    targetUid,
                                  );
                                },
                                child: Text(
                                  isFollowingTarget ? 'Following' : 'Follow',
                                  style: TextStyle(
                                    color: isFollowingTarget
                                        ? textColor
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
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
