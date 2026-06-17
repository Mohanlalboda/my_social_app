// lib/screens/communities/communities_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../chat/group_chat_room_screen.dart';

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  final List<Map<String, dynamic>> communityGroups = [
    {
      "id": "notice_board",
      "name": "📢 Notice Board",
      "desc": "Official updates from Village Panchayat",
      "color": Colors.orangeAccent,
      "icon": Icons.campaign_rounded,
    },
    {
      "id": "youth_club",
      "name": "💪 Youth Association",
      "desc": "Discussions, events & sports",
      "color": Colors.blueAccent,
      "icon": Icons.sports_volleyball_rounded,
    },
    {
      "id": "jobs_alerts",
      "name": "💼 Jobs & Opportunities",
      "desc": "Local job alerts and career help",
      "color": Colors.green,
      "icon": Icons.work_outline_rounded,
    },
    {
      "id": "women_group",
      "name": "👩‍🦰 Women Empowerment",
      "desc": "Welfare, self-help groups & discussions",
      "color": Colors.pinkAccent,
      "icon": Icons.diversity_1_rounded,
    },
    {
      "id": "festivals",
      "name": "🎉 Festivals & Events",
      "desc": "Temple festivals, Jataras and celebrations",
      "color": Colors.purpleAccent,
      "icon": Icons.celebration_rounded,
    },
  ];

  // 🌟 THE FIX: పక్కా జాయిన్ లాజిక్ (పర్మిషన్ తో)
  void _handleGroupClick(String villageName, Map<String, dynamic> group) async {
    // ఊరి పేరులోని స్పేస్ లు తీసేసి, చిన్న అక్షరాలతో ఐడీ క్రియేట్ చేస్తున్నాం (డూప్లికేట్స్ రాకుండా)
    String cleanVillageName = villageName.replaceAll(' ', '_').toLowerCase();
    String groupId = "comm_${cleanVillageName}_${group['id']}";
    String groupName = "${group['name']} ($villageName)";

    // లోడింగ్ చూపిస్తున్నాం..
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    DocumentReference groupRef = FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(groupId);
    DocumentSnapshot doc = await groupRef.get();

    if (!mounted) return;
    Navigator.pop(context); // లోడింగ్ క్లోజ్

    if (doc.exists) {
      // 1️⃣ గ్రూప్ ముందే క్రియేట్ అయి ఉంది.
      var data = doc.data() as Map<String, dynamic>;
      List users = data['users'] ?? [];

      if (users.contains(currentUid)) {
        // ఆల్రెడీ జాయిన్ అయి ఉన్నాడు కాబట్టి డైరెక్ట్ గా చాట్ ఓపెన్ అవుతుంది.
        _goToChat(groupId, groupName);
      } else {
        // ఇంకా జాయిన్ అవ్వలేదు కాబట్టి పర్మిషన్ అడుగుతాం
        _showJoinDialog(groupRef, groupId, groupName, users.length, false);
      }
    } else {
      // 2️⃣ అసలు ఆ ఊరికి ఆ గ్రూప్ ఇంకా ఎవరూ స్టార్ట్ చేయలేదు.
      _showJoinDialog(groupRef, groupId, groupName, 0, true);
    }
  }

  // 🌟 పర్మిషన్ అడిగే పాపప్ డిజైన్
  void _showJoinDialog(
    DocumentReference groupRef,
    String groupId,
    String groupName,
    int membersCount,
    bool isFirst,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isFirst ? 'Start Community 🚀' : 'Join Community 🤝',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 35,
              backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
              child: const Icon(
                Icons.groups_rounded,
                size: 40,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              isFirst
                  ? "You are the first person to join $groupName! Start the community now."
                  : "Do you want to join $groupName? Currently it has $membersCount members.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);

              if (isFirst) {
                // కొత్తగా క్రియేట్ చేస్తున్నాం
                await groupRef.set({
                  'chatRoomId': groupId,
                  'groupName': groupName,
                  'groupPic':
                      'https://cdn-icons-png.flaticon.com/512/1256/1256073.png',
                  'isGroup': true,
                  'isCommunity': true,
                  'village': groupName
                      .split('(')
                      .last
                      .replaceAll(')', '')
                      .trim(),
                  'users': [currentUid],
                  'admins': [currentUid],
                  'lastMessage': 'Welcome to $groupName! 🏡',
                  'timestamp': FieldValue.serverTimestamp(),
                });
              } else {
                // ఉన్న గ్రూప్ లో జాయిన్ అవుతున్నాడు
                await groupRef.update({
                  'users': FieldValue.arrayUnion([currentUid]),
                });
              }
              _goToChat(groupId, groupName);
            },
            child: Text(
              isFirst ? "Start Group" : "Join Now",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goToChat(String groupId, String groupName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupChatRoomScreen(
          groupId: groupId,
          groupName: groupName,
          groupPic: 'https://cdn-icons-png.flaticon.com/512/1256/1256073.png',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        title: Text(
          'Communities 🏡',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: textColor,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("User data not found"));
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>;
          String villageName = userData['village'] ?? '';

          if (villageName.trim().isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.holiday_village_rounded,
                      size: 80,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Village Not Set! 🏜️",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Please update your village name in your profile to join your local communities.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              // 🌟 హెడర్ కార్డ్
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade700, Colors.teal.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "Your Village Community",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        const Icon(
                          Icons.home_work_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            villageName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Connect, share, and grow together with your own people.",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 5),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Community Groups 🏘️",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),

              // 🌟 సబ్-గ్రూప్స్ లిస్ట్
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: communityGroups.length,
                  itemBuilder: (context, index) {
                    var group = communityGroups[index];
                    return Card(
                      color: isDark ? Colors.grey[900] : Colors.white,
                      elevation: 0.5,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(
                          color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          radius: 25,
                          backgroundColor: (group['color'] as Color).withValues(
                            alpha: 0.15,
                          ),
                          child: Icon(
                            group['icon'],
                            color: group['color'],
                            size: 28,
                          ),
                        ),
                        title: Text(
                          group['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            group['desc'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.grey,
                        ),

                        // ఇక్కడే మన మ్యాజిక్ లాజిక్ ని కనెక్ట్ చేసాం 👇
                        onTap: () => _handleGroupClick(villageName, group),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
