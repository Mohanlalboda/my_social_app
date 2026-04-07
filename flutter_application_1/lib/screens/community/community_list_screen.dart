import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../widgets/safe_elements.dart';
import 'community_chat_screen.dart';
import 'create_community_screen.dart';

class CommunityListScreen extends StatefulWidget {
  const CommunityListScreen({super.key});

  @override
  State<CommunityListScreen> createState() => _CommunityListScreenState();
}

class _CommunityListScreenState extends State<CommunityListScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  // 🌟 స్వైప్ చేసి హైడ్ చేసే ఫంక్షన్
  void _hideGroup(String groupId) async {
    await FirebaseFirestore.instance.collection('communities').doc(groupId).set(
      {
        'deletedBy': FieldValue.arrayUnion([currentUid]),
      },
      SetOptions(merge: true),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Group hidden"),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // 🌟 క్రియేట్ గ్రూప్ స్క్రీన్‌కి వెళ్లే ఫంక్షన్
  void _navigateToCreateGroup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateCommunityScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,

      // ✅ 1. AppBar పూర్తిగా తీసేశాను (నో టైటిల్, నో బ్యాక్ యారో, నో ప్లస్ ఐకాన్)
      appBar: null,

      // ✅ 2. కింద బ్లూ కలర్ "Add Group" బటన్
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00E5FF), // బ్లూ/సియాన్ కలర్
        onPressed: _navigateToCreateGroup,
        child: const Icon(Icons.group_add, color: Colors.black, size: 28),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('communities')
            .where('members', arrayContains: currentUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No communities yet. Tap + to start! 🚀",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          // 'deletedBy' ఫిల్టరింగ్
          var visibleGroups = snapshot.data!.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            List deletedBy = data['deletedBy'] ?? [];
            return !deletedBy.contains(currentUid);
          }).toList();

          // టైమ్ సార్టింగ్
          visibleGroups.sort((a, b) {
            Timestamp? t1 = (a.data() as Map)['timestamp'] as Timestamp?;
            Timestamp? t2 = (b.data() as Map)['timestamp'] as Timestamp?;
            if (t1 == null && t2 == null) return 0;
            if (t1 == null) return 1;
            if (t2 == null) return -1;
            return t2.compareTo(t1);
          });

          if (visibleGroups.isEmpty) {
            return const Center(
              child: Text(
                "No active communities.",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 10), // పైన కొంచెం గ్యాప్
            itemCount: visibleGroups.length,
            itemBuilder: (context, index) {
              var groupData =
                  visibleGroups[index].data() as Map<String, dynamic>;
              String groupId = visibleGroups[index].id;
              String groupName = groupData['groupName'] ?? 'Community';
              String groupPic = groupData['groupPic'] ?? '';
              String lastMsg = groupData['lastMessage'] ?? 'Tap to chat';
              DateTime time =
                  (groupData['timestamp'] as Timestamp?)?.toDate() ??
                  DateTime.now();

              return Dismissible(
                key: Key(groupId),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) => _hideGroup(groupId),
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                child: ListTile(
                  leading: SafeProfilePic(
                    base64String: groupPic,
                    radius: 25,
                    fallbackText: groupName.isNotEmpty
                        ? groupName[0].toUpperCase()
                        : 'C',
                  ),
                  title: Text(
                    groupName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    lastMsg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  trailing: Text(
                    timeago.format(time, locale: 'en_short'),
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommunityChatScreen(
                          communityId: groupId,
                          communityName: groupName,
                          communityIcon: groupPic,
                        ),
                      ),
                    );
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
