import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../widgets/safe_elements.dart';
import 'create_community_screen.dart';
import 'community_chat_screen.dart'; // 🌟 మన చాట్ స్క్రీన్ ఇంపోర్ట్ చేశాం

class CommunityListScreen extends StatelessWidget {
  const CommunityListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser!.uid;
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateCommunityScreen()),
        ),
        backgroundColor: const Color(0xFF833AB4),
        child: const Icon(Icons.group_add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🌟 ఫైర్‌బేస్ ఇండెక్స్ ఎర్రర్ రాకుండా క్వెరీ
        stream: FirebaseFirestore.instance
            .collection('communities')
            .where('members', arrayContains: currentUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Something went wrong"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 🌟 మ్యాన్యువల్ గా సార్ట్ చేస్తున్నాం (లేటెస్ట్ మెసేజ్ పైకి రావడానికి)
          var communities = snapshot.data!.docs.toList();
          communities.sort((a, b) {
            var aData = a.data() as Map<String, dynamic>;
            var bData = b.data() as Map<String, dynamic>;
            Timestamp? t1 = aData['lastMessageTime'] as Timestamp?;
            Timestamp? t2 = bData['lastMessageTime'] as Timestamp?;
            if (t1 == null && t2 == null) return 0;
            if (t1 == null) return 1;
            if (t2 == null) return -1;
            return t2.compareTo(t1);
          });

          if (communities.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.groups_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 10),
                  Text(
                    "You haven't joined any communities yet.",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: communities.length,
            itemBuilder: (context, index) {
              var data = communities[index].data() as Map<String, dynamic>;
              String name = data['name'] ?? "Community";
              String icon = data['groupIcon'] ?? "";
              String lastMsg = data['lastMessage'] ?? "";
              DateTime time =
                  (data['lastMessageTime'] as Timestamp?)?.toDate() ??
                  DateTime.now();

              return ListTile(
                leading: SafeProfilePic(
                  base64String: icon,
                  radius: 25,
                  fallbackText: name.isNotEmpty ? name[0].toUpperCase() : 'C',
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Text(
                  lastMsg,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey),
                ),
                trailing: Text(
                  timeago.format(time, locale: 'en_short'),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                onTap: () {
                  // 🌟 మ్యాజిక్: ఇప్పుడు డైరెక్ట్ గా వాట్సాప్ గ్రూప్ లాంటి చాట్ ఓపెన్ అవుతుంది!
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommunityChatScreen(
                        communityId: communities[index].id,
                        communityName: name,
                        communityIcon: icon,
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
