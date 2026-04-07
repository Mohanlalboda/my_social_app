// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'safe_elements.dart'; // మీ SafeProfilePic పాత్ చెక్ చేసుకోండి

class SuggestedFriendsWidget extends StatelessWidget {
  const SuggestedFriendsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser!.uid;
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      // 1. ముందు మన డేటా (మనం ఎవరిని ఫాలో అవుతున్నామో) తెచ్చుకోవాలి
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .snapshots(),
      builder: (context, mySnapshot) {
        if (!mySnapshot.hasData) return const SizedBox();

        var myData = mySnapshot.data!.data() as Map<String, dynamic>? ?? {};
        List myFollowing = myData['following'] ?? [];

        return StreamBuilder<QuerySnapshot>(
          // 2. మిగతా యూజర్స్ అందరినీ (లేదా కొందరిని) తెచ్చుకోవాలి
          stream: FirebaseFirestore.instance
              .collection('users')
              .limit(20)
              .snapshots(),
          builder: (context, usersSnapshot) {
            if (!usersSnapshot.hasData) return const SizedBox();

            // మన ఐడీ కాకుండా, మిగతా యూజర్స్ ని ఫిల్టర్ చేయాలి
            var suggestedUsers = usersSnapshot.data!.docs.where((doc) {
              return doc.id != currentUid;
            }).toList();

            if (suggestedUsers.isEmpty) return const SizedBox();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  child: Text(
                    "Suggested for you",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: suggestedUsers.length,
                    itemBuilder: (context, index) {
                      var userDoc = suggestedUsers[index];
                      var userData = userDoc.data() as Map<String, dynamic>;
                      String targetUid = userDoc.id;

                      // 🌟 మ్యాజిక్ లాజిక్: Mutual Friends కౌంట్
                      List targetFollowers = userData['followers'] ?? [];
                      int mutualCount = myFollowing
                          .where((id) => targetFollowers.contains(id))
                          .length;

                      // 🌟 Follow / Following స్టేటస్
                      bool isFollowing = myFollowing.contains(targetUid);

                      return _SuggestedUserCard(
                        targetUid: targetUid,
                        userData: userData,
                        isFollowing: isFollowing,
                        mutualCount: mutualCount,
                        currentUid: currentUid,
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
}

// 🌟 ఒక్కో యూజర్ కి సంబంధించిన కార్డ్ డిజైన్ (Follow/Unfollow లాజిక్ తో సహా)
class _SuggestedUserCard extends StatelessWidget {
  final String targetUid;
  final Map<String, dynamic> userData;
  final bool isFollowing;
  final int mutualCount;
  final String currentUid;

  const _SuggestedUserCard({
    required this.targetUid,
    required this.userData,
    required this.isFollowing,
    required this.mutualCount,
    required this.currentUid,
  });

  // 🌟 Follow / Unfollow బటన్ లాజిక్
  void _toggleFollow() async {
    if (isFollowing) {
      // Unfollow
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .update({
            'following': FieldValue.arrayRemove([targetUid]),
          });
      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .update({
            'followers': FieldValue.arrayRemove([currentUid]),
          });
    } else {
      // Follow
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .update({
            'following': FieldValue.arrayUnion([targetUid]),
          });
      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .update({
            'followers': FieldValue.arrayUnion([currentUid]),
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 140,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 1. ప్రొఫైల్ పిక్
          SafeProfilePic(
            base64String: userData['profilePic'] ?? '',
            radius: 35,
            fallbackText: (userData['username'] ?? 'U')[0].toUpperCase(),
          ),
          const SizedBox(height: 10),

          // 2. యూజర్ నేమ్
          Text(
            userData['username'] ?? 'User',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),

          // 3. Mutual Friends టెక్స్ట్ (ఉంటేనే చూపిస్తుంది)
          Text(
            mutualCount > 0
                ? "$mutualCount mutual friends"
                : "Suggested for you",
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const Spacer(),

          // 4. Follow / Following బటన్
          SizedBox(
            width: double.infinity,
            height: 32,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowing
                    ? Colors.grey[300]
                    : const Color(
                        0xFF00E5FF,
                      ), // ఫాలో అయితే గ్రే, లేకపోతే నియాన్ బ్లూ
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _toggleFollow,
              child: Text(
                isFollowing ? "Following" : "Follow",
                style: TextStyle(
                  color: isFollowing ? Colors.black87 : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
