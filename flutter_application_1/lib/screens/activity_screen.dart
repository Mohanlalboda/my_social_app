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
  @override
  void initState() {
    super.initState();
    _markNotificationsAsRead();
  }

  void _markNotificationsAsRead() async {
    String currentUid = FirebaseAuth.instance.currentUser!.uid;
    var unreadDocs = await FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isEqualTo: currentUid)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in unreadDocs.docs) {
      doc.reference.update({'isRead': true});
    }
  }

  @override
  Widget build(BuildContext context) {
    String currentUid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      // 🌟 FIXED: app_bar change to appBar
      appBar: AppBar(title: const Text("Activity")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('receiverId', isEqualTo: currentUid)
            .snapshots(),
        builder: (context, snapshot) {
          // 🌟 FIXED: Added curly braces for 'if' blocks
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No notifications yet."));
          }

          var docs = snapshot.data!.docs.toList();
          docs.sort((a, b) {
            Timestamp t1 = (a.data() as Map)['timestamp'] ?? Timestamp.now();
            Timestamp t2 = (b.data() as Map)['timestamp'] ?? Timestamp.now();
            return t2.compareTo(t1);
          });

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var notif = docs[index].data() as Map<String, dynamic>;
              String timeStr = notif['timestamp'] != null
                  ? timeago.format(
                      (notif['timestamp'] as Timestamp).toDate(),
                      locale: 'en_short',
                    )
                  : "";
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.notifications)),
                title: Text(
                  "${notif['senderName'] ?? 'Someone'} ${notif['type']}d your post.",
                ),
                trailing: Text(timeStr),
              );
            },
          );
        },
      ),
    );
  }
}
