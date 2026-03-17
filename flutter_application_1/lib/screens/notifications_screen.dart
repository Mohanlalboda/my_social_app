import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'post_details_screen.dart';
// import 'single_reel_screen.dart'; // ఒకవేళ రీల్స్ కి కూడా లింక్ చేయాలంటే ఇది వాడతాం

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Activity",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('receiverId', isEqualTo: currentUid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No notifications yet. 📭",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          var notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              var notif = notifications[index].data() as Map<String, dynamic>;
              String docId = notifications[index].id;

              String type = notif['type'] ?? '';
              String senderName = notif['senderName'] ?? 'User';
              bool isRead = notif['isRead'] ?? false;

              // 🌟 టైమ్ ఫార్మాట్ (ఉదాహరణకు: 2m ago, 1h ago)
              String timeStr = "Just now";
              if (notif['timestamp'] != null) {
                timeStr = timeago.format(
                  (notif['timestamp'] as Timestamp).toDate(),
                  locale: 'en_short',
                );
              }

              // 🌟 నోటిఫికేషన్ రకాన్ని బట్టి ఐకాన్ మరియు టెక్స్ట్ మారుతుంది
              IconData iconData;
              Color iconColor;
              String actionText;

              if (type == 'like') {
                iconData = Icons.favorite;
                iconColor = Colors.red;
                actionText = "liked your post.";
              } else if (type == 'comment') {
                iconData = Icons.comment;
                iconColor = Colors.blue;
                actionText = "commented on your post.";
              } else if (type == 'follow') {
                iconData = Icons.person_add;
                iconColor = Colors.green;
                actionText = "started following you.";
              } else {
                iconData = Icons.notifications;
                iconColor = Colors.orange;
                actionText = "interacted with you.";
              }

              return Container(
                // చూడని నోటిఫికేషన్స్ కి లైట్ బ్లూ కలర్ బ్యాక్‌గ్రౌండ్ వస్తుంది
                color: isRead
                    ? Colors.transparent
                    : Colors.blue.withValues(alpha: 0.08),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey[300],
                        child: Text(
                          senderName.isNotEmpty
                              ? senderName[0].toUpperCase()
                              : "?",
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 8,
                            backgroundColor: iconColor,
                            child: Icon(
                              iconData,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black, fontSize: 14),
                      children: [
                        TextSpan(
                          text: "$senderName ",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: actionText),
                      ],
                    ),
                  ),
                  trailing: Text(
                    timeStr,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  onTap: () {
                    // 🌟 క్లిక్ చేయగానే అది Read అయినట్టు అప్‌డేట్ అవుతుంది (బ్లూ కలర్ పోతుంది)
                    FirebaseFirestore.instance
                        .collection('notifications')
                        .doc(docId)
                        .update({'isRead': true});

                    // 🌟 పోస్ట్ కి సంబంధించిన నోటిఫికేషన్ అయితే ఆ పోస్ట్ ఓపెన్ అవుతుంది
                    if (notif['postId'] != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PostDetailsScreen(postId: notif['postId']),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
