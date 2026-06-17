// lib/screens/chat/users_list_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 🌟 Added
import 'chat_room_screen.dart';

class UsersListScreen extends StatelessWidget {
  const UsersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        title: const Text(
          'Messages 💬',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder:
            (
              context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No Users Found'));
              }

              // మన ఐడీ కాకుండా మిగతా యూజర్లను ఫిల్టర్ చేస్తున్నాం
              var users = snapshot.data!.docs
                  .where((doc) => doc.id != currentUid)
                  .toList();

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  var user = users[index].data();
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user['profilePic'].toString().isNotEmpty
                          ? CachedNetworkImageProvider(
                              user['profilePic'],
                            ) // 🌟 Cache Applied
                          : const CachedNetworkImageProvider(
                              'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                            ),
                    ),
                    title: Text(
                      user['username'] ?? 'User',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      user['bio'] ?? 'Hey there!',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      // యూజర్ పై క్లిక్ చేయగానే చాట్ రూమ్ కి వెళ్తాం
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatRoomScreen(
                            receiverUid: user['uid'],
                            receiverUsername: user['username'] ?? 'User',
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
