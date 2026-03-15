import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    // 🌟 యాక్టివిటీ స్క్రీన్ మూసేసి బ్యాక్ వెళ్ళగానే అన్నీ 'Read' అయిపోతాయి (Red dot పోతుంది)
    _markAllAsRead();
    super.dispose();
  }

  Future<void> _markAllAsRead() async {
    var unreadDocs = await FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isEqualTo: currentUid)
        .where('isRead', isEqualTo: false)
        .get();

    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var doc in unreadDocs.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // 🌟 క్లియర్ ఆల్ ఫంక్షన్ (అన్నీ డిలీట్ చేయడానికి)
  Future<void> _clearAll() async {
    var allDocs = await FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isEqualTo: currentUid)
        .get();

    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var doc in allDocs.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Activity"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.red),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Clear All"),
                  content: const Text("Delete all notifications?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () {
                        _clearAll();
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "Clear",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('receiverId', isEqualTo: currentUid)
            .snapshots(),
        builder: (context, snapshot) {
          // 🌟 కర్లీ బ్రాకెట్స్ ఫిక్స్ చేసాము
          if (snapshot.hasError) {
            return const Center(child: Text("Something went wrong!"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var notifications = snapshot.data!.docs.toList();

          notifications.sort((a, b) {
            var dataA = a.data() as Map<String, dynamic>;
            var dataB = b.data() as Map<String, dynamic>;
            Timestamp? tA = dataA['timestamp'];
            Timestamp? tB = dataB['timestamp'];
            // 🌟 కర్లీ బ్రాకెట్స్ ఫిక్స్ చేసాము
            if (tA == null) {
              return 1;
            }
            if (tB == null) {
              return -1;
            }
            return tB.compareTo(tA);
          });

          // 🌟 కర్లీ బ్రాకెట్స్ ఫిక్స్ చేసాము
          if (notifications.isEmpty) {
            return const Center(child: Text("No new activity"));
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              var notif = notifications[index].data() as Map<String, dynamic>;
              bool isRead = notif['isRead'] ?? true;

              String timeStr = notif['timestamp'] != null
                  ? timeago.format((notif['timestamp'] as Timestamp).toDate())
                  : "Just now";

              String actionText = "";
              IconData iconData = Icons.notifications;
              Color iconColor = Colors.blue;

              if (notif['type'] == 'like') {
                actionText = "liked your post.";
                iconData = Icons.favorite;
                iconColor = Colors.red;
              } else if (notif['type'] == 'comment') {
                actionText = "commented on your post.";
                iconData = Icons.comment;
                iconColor = Colors.green;
              } else if (notif['type'] == 'follow') {
                actionText = "started following you.";
                iconData = Icons.person_add;
                iconColor = Colors.blue;
              }

              return ListTile(
                // 🌟 FIX: withOpacity బదులు లేటెస్ట్ withValues వాడాము
                tileColor: isRead
                    ? Colors.transparent
                    : Colors.blue.withValues(alpha: 0.05),
                leading: CircleAvatar(
                  // 🌟 FIX: withOpacity బదులు లేటెస్ట్ withValues వాడాము
                  backgroundColor: iconColor.withValues(alpha: 0.2),
                  child: Icon(iconData, color: iconColor, size: 20),
                ),
                title: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                    children: [
                      TextSpan(
                        text: "${notif['senderName']} ",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: actionText),
                    ],
                  ),
                ),
                subtitle: Text(
                  timeStr,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
