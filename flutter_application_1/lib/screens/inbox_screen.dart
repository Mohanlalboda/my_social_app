import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/safe_elements.dart';
import 'chat_screen.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    String currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("Messages")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var users = snapshot.data!.docs
              .where((doc) => doc.id != currentUid)
              .toList();

          if (users.isEmpty) {
            return const Center(child: Text("No users found to chat with."));
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              var u = users[index].data() as Map<String, dynamic>;
              String roomId = currentUid.hashCode <= u['uid'].hashCode
                  ? "${currentUid}_${u['uid']}"
                  : "${u['uid']}_$currentUid";

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chatRooms')
                    .doc(roomId)
                    .snapshots(),
                builder: (context, roomSnapshot) {
                  var d = roomSnapshot.data?.data() as Map<String, dynamic>?;

                  // 🌟 ఇక్కడ ఆ పర్టిక్యులర్ యూజర్ నుండి వచ్చిన "చూడని" మెసేజ్ ల కౌంట్ తీసుకుంటున్నాం
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('messages')
                        .where('receiverId', isEqualTo: currentUid)
                        .where('senderId', isEqualTo: u['uid'])
                        .where('isRead', isEqualTo: false)
                        .snapshots(),
                    builder: (context, unreadSnapshot) {
                      int unreadCount = unreadSnapshot.hasData
                          ? unreadSnapshot.data!.docs.length
                          : 0;
                      bool isUnread = unreadCount > 0;

                      return ListTile(
                        leading: SafeProfilePic(
                          base64String: u['profilePic'],
                          radius: 25,
                          fallbackText: u['username'] ?? "U",
                        ),
                        title: Text(
                          u['username'] ?? "",
                          style: TextStyle(
                            fontWeight: isUnread
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          d?['lastMessage'] ?? "Tap to chat",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isUnread ? Colors.black : Colors.grey,
                          ),
                        ),
                        // 🌟 రెడ్ డాట్ తో పాటు మెసేజ్ ల కౌంట్ ఇక్కడ వస్తుంది!
                        trailing: isUnread
                            ? Badge(
                                label: Text(unreadCount.toString()),
                                backgroundColor: Colors.red,
                              )
                            : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                receiverId: u['uid'],
                                receiverName: u['username'],
                              ),
                            ),
                          );
                        },
                      );
                    },
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
