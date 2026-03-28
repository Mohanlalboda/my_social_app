// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../widgets/safe_elements.dart';
import 'other_user_profile_screen.dart';
import 'scrolling_posts_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  // 🌟 నోటిఫికేషన్ చదివినట్టు మార్చడానికి
  void _markAsRead(String docId) {
    FirebaseFirestore.instance.collection('notifications').doc(docId).update({
      'isRead': true,
    });
  }

  // 🌟 సింగిల్ నోటిఫికేషన్ డిలీట్ చేయడానికి (స్వైప్ చేసినప్పుడు)
  void _deleteNotification(String docId) {
    FirebaseFirestore.instance.collection('notifications').doc(docId).delete();
  }

  // 🌟 మొత్తం నోటిఫికేషన్స్ క్లియర్ చేయడానికి (Clear All)
  void _clearAllNotifications() async {
    bool? confirm = await showDialog<bool>(
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
            child: const Text("Clear All", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // ఫైర్‌బేస్ లో బల్క్ (Bulk) గా డిలీట్ చేయడానికి batch వాడుతున్నాం
      var batch = FirebaseFirestore.instance.batch();
      var notifs = await FirebaseFirestore.instance
          .collection('notifications')
          .where('receiverId', isEqualTo: currentUid)
          .get();

      for (var doc in notifs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("All notifications cleared! 🗑️"),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        title: Text(
          "Activity",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        // 🌟 Clear All బటన్ ని పైన యాడ్ చేశాం!
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.red),
            tooltip: "Clear All Notifications",
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "No notifications yet.",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          var notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              var notif = notifications[index].data() as Map<String, dynamic>;
              String notifId = notifications[index].id;

              String type = notif['type'] ?? '';
              String senderId = notif['senderId'] ?? '';
              bool isRead = notif['isRead'] ?? false;

              String timeStr = "Just now";
              if (notif['timestamp'] != null) {
                timeStr = timeago.format(
                  (notif['timestamp'] as Timestamp).toDate(),
                );
              }

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(senderId)
                    .get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData || !userSnap.data!.exists) {
                    return const SizedBox();
                  }

                  var senderData =
                      userSnap.data!.data() as Map<String, dynamic>;
                  String username = senderData['username'] ?? "User";

                  IconData notifIcon;
                  Color iconColor;
                  String notifMessage;

                  if (type == 'like') {
                    notifIcon = Icons.favorite;
                    iconColor = Colors.red;
                    notifMessage = "liked your post.";
                  } else if (type == 'comment') {
                    notifIcon = Icons.comment;
                    iconColor = Colors.blue;
                    notifMessage = "commented: ${notif['text'] ?? ''}";
                  } else if (type == 'follow') {
                    notifIcon = Icons.person_add;
                    iconColor = Colors.green;
                    notifMessage = "started following you.";
                  } else {
                    notifIcon = Icons.notifications;
                    iconColor = Colors.grey;
                    notifMessage = "interacted with you.";
                  }

                  // 🌟 Swipe To Delete కోసం Dismissible విడ్జెట్ యాడ్ చేశాం!
                  return Dismissible(
                    key: Key(notifId),
                    direction:
                        DismissDirection.endToStart, // కుడి నుండి ఎడమకు స్వైప్
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      color: Colors.red,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (direction) {
                      _deleteNotification(notifId);
                    },
                    child: Container(
                      color: isRead
                          ? Colors.transparent
                          : (isDark
                                ? Colors.grey.withValues(alpha: 0.2)
                                : Colors.blue.withValues(alpha: 0.1)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 8,
                        ),
                        onTap: () {
                          if (!isRead) {
                            _markAsRead(notifId);
                          }

                          // నావిగేషన్ పక్కాగా యాడ్ చేశాం!
                          if (type == 'follow') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    OtherUserProfileScreen(userId: senderId),
                              ),
                            );
                          } else if ((type == 'like' || type == 'comment') &&
                              notif['postId'] != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ScrollingPostsScreen(
                                  postIds: [notif['postId']],
                                  initialIndex: 0,
                                ),
                              ),
                            );
                          }
                        },
                        leading: Stack(
                          children: [
                            SafeProfilePic(
                              base64String: senderData['profilePic'],
                              radius: 25,
                              fallbackText: username[0].toUpperCase(),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.black : Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  notifIcon,
                                  color: iconColor,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        title: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: "$username ",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(text: notifMessage),
                            ],
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            timeStr,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
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
