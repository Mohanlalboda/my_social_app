// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../widgets/safe_elements.dart';
import 'other_user_profile_screen.dart';
import 'single_post_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  // 🌟 అన్నీ ఒకేసారి డిలీట్ చేయడానికి లాజిక్
  void _clearAllNotifications() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear All?"),
        content: const Text(
          "Are you sure you want to delete all notifications?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Delete All",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      var snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('receiverId', isEqualTo: currentUid)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All notifications cleared! ✅")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color textColor =
        Theme.of(context).textTheme.bodyLarge?.color ??
        (isDark ? Colors.white : Colors.black);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Activity",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        // 🌟 పైన "Clear All" ఐకాన్ యాడ్ చేశాం
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            onPressed: _clearAllNotifications,
          ),
        ],
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
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          var notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              var notif = notifications[index].data() as Map<String, dynamic>;
              String type = notif['type'] ?? '';
              String senderId = notif['senderId'] ?? '';
              String postId = notif['postId'] ?? '';
              bool isRead = notif['isRead'] ?? false;

              DateTime time =
                  (notif['timestamp'] as Timestamp?)?.toDate() ??
                  DateTime.now();
              String timeAgo = timeago.format(time);

              if (!isRead) {
                FirebaseFirestore.instance
                    .collection('notifications')
                    .doc(notifications[index].id)
                    .update({'isRead': true});
              }

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(senderId)
                    .get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData || !userSnap.data!.exists)
                    return const SizedBox();

                  var userData = userSnap.data!.data() as Map<String, dynamic>;
                  String username = userData['username'] ?? 'User';
                  String profilePic = userData['profilePic'] ?? '';

                  String actionText = "";
                  if (type == 'like') {
                    actionText = "liked your post.";
                  } else if (type == 'comment') {
                    actionText =
                        "commented: ${notif['commentText'] ?? 'on your post'}.";
                  } else if (type == 'follow') {
                    actionText = "started following you.";
                  } else {
                    actionText = "interacted with you.";
                  }

                  // 🌟 ఇక్కడే మ్యాజిక్! Swipe to Delete (Dismissible) వాడాం
                  return Dismissible(
                    key: Key(notifications[index].id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (direction) {
                      // 🌟 పక్కకి స్వైప్ చేయగానే డేటాబేస్ నుండి డిలీట్ అవుతుంది
                      FirebaseFirestore.instance
                          .collection('notifications')
                          .doc(notifications[index].id)
                          .delete();
                    },
                    child: InkWell(
                      onTap: () {
                        if (type == 'follow') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  OtherUserProfileScreen(userId: senderId),
                            ),
                          );
                        } else if (type == 'like' || type == 'comment') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SinglePostScreen(postId: postId),
                            ),
                          );
                        }
                      },
                      child: Container(
                        color: isRead
                            ? Colors.transparent
                            : (isDark
                                  ? Colors.white10
                                  : Colors.blue.withValues(alpha: 0.1)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      OtherUserProfileScreen(userId: senderId),
                                ),
                              ),
                              child: SafeProfilePic(
                                base64String: profilePic,
                                radius: 22,
                                fallbackText: username.isNotEmpty
                                    ? username[0]
                                    : 'U',
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                    fontFamily: 'Poppins',
                                  ),
                                  children: [
                                    TextSpan(
                                      text: "$username ",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(text: actionText),
                                    TextSpan(
                                      text: "  $timeAgo",
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (type == 'like' || type == 'comment')
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.grey,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
