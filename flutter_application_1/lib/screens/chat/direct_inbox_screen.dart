import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart'; // 🌟 THE FIX: Image Caching
import '../../widgets/banjara_notes_bar.dart'; // 🌟 THE FIX: Notes bar import

import 'chat_room_screen.dart';
import 'group_chat_room_screen.dart';
import 'new_chat_screen.dart';

class DirectInboxScreen extends StatefulWidget {
  const DirectInboxScreen({super.key});

  @override
  State<DirectInboxScreen> createState() => _DirectInboxScreenState();
}

class _DirectInboxScreenState extends State<DirectInboxScreen>
    with SingleTickerProviderStateMixin {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  late TabController _inboxTabController;

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

  @override
  void initState() {
    super.initState();
    _inboxTabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _inboxTabController.dispose();
    super.dispose();
  }

  void _handleCommunityClick(
    String villageName,
    Map<String, dynamic> group,
  ) async {
    String cleanVillageName = villageName.replaceAll(' ', '_').toLowerCase();
    String groupId = "comm_${cleanVillageName}_${group['id']}";
    String groupName = "${group['name']} ($villageName)";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      ),
    );

    DocumentReference groupRef = FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(groupId);
    DocumentSnapshot doc = await groupRef.get();

    if (!mounted) return;
    Navigator.pop(context);

    if (doc.exists) {
      var data = doc.data() as Map<String, dynamic>;
      List users = data['users'] ?? [];

      if (users.contains(currentUid)) {
        _goToGroupChat(groupId, groupName);
      } else {
        _showJoinPermissionDialog(
          groupRef,
          groupId,
          groupName,
          users.length,
          false,
        );
      }
    } else {
      _showJoinPermissionDialog(groupRef, groupId, groupName, 0, true);
    }
  }

  void _showJoinPermissionDialog(
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
              backgroundColor: Colors.blueAccent.withAlpha(38),
              child: const Icon(
                Icons.groups_rounded,
                size: 40,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              isFirst
                  ? "You are the first person to join $groupName! Start this village community group."
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
                await groupRef.update({
                  'users': FieldValue.arrayUnion([currentUid]),
                });
              }
              _goToGroupChat(groupId, groupName);
            },
            child: Text(
              isFirst ? "Start" : "Join Now",
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

  void _goToGroupChat(String groupId, String groupName) {
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
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0, // 🌟 THE FIX: UI neat ga blend avvadaniki 0 chesam
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          'Messages ✉️',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: textColor,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.rate_review_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NewChatScreen()),
            ),
          ),
        ],
        // ఇక్కడ ఉన్న bottom: TabBar(...) ని తీసేసి కింద body లో పెట్టాం
      ),
      body: Column(
        children: [
          // 🌟 1. ఇక్కడే మన నోట్స్ బార్ వస్తుంది (App Bar కింద, Tabs కి పైన)
          const BanjaraNotesBar(),

          // 🌟 2. ఆ తర్వాత Tabs (Chats, Groups, Communities) వస్తాయి
          TabBar(
            controller: _inboxTabController,
            indicatorColor: Colors.blueAccent,
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            tabs: const [
              Tab(text: "Chats"),
              Tab(text: "Groups"),
              Tab(text: "Communities"),
              Tab(text: "Calls"),
            ],
          ),

          // 🌟 3. ఫైనల్ గా ఆయా ట్యాబ్స్ కి సంబంధించిన చాట్ లిస్ట్ వస్తుంది
          Expanded(
            child: TabBarView(
              controller: _inboxTabController,
              children: [
                _buildPersonalChatsTab(isDark),
                _buildNormalGroupsTab(isDark),
                _buildCommunitiesTab(isDark),
                _buildCallsTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalChatsTab(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_rooms')
          .where('users', arrayContains: currentUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const Center(
            child: Text(
              'No Personal Chats Yet. 👋',
              style: TextStyle(color: Colors.grey),
            ),
          );

        var chatDocs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return data['isGroup'] != true;
        }).toList();

        if (chatDocs.isEmpty)
          return const Center(
            child: Text(
              'No Personal Chats Yet. 👋',
              style: TextStyle(color: Colors.grey),
            ),
          );

        return ListView.builder(
          itemCount: chatDocs.length,
          itemBuilder: (context, index) {
            var chatData = chatDocs[index].data() as Map<String, dynamic>;
            List users = chatData['users'] ?? [];
            String receiverUid = users.firstWhere(
              (id) => id != currentUid,
              orElse: () => "",
            );

            String lastMessage = chatData['lastMessage'] ?? 'No message';
            bool isRead = chatData['isRead'] ?? true;
            String lastSender = chatData['lastMessageSender'] ?? '';
            bool showUnreadBadge = !isRead && lastSender != currentUid;
            Timestamp? ts = chatData['timestamp'] as Timestamp?;
            DateTime msgTime = ts != null ? ts.toDate() : DateTime.now();

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(receiverUid)
                  .get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData || !userSnap.data!.exists)
                  return const SizedBox.shrink();
                var uData = userSnap.data!.data() as Map<String, dynamic>;
                String uName = uData['username'] ?? 'Banjara User';
                String pPic = uData['profilePic'] ?? '';

                return ListTile(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatRoomScreen(
                        receiverUid: receiverUid,
                        receiverUsername: uName,
                      ),
                    ),
                  ),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundImage: pPic.isNotEmpty
                        ? CachedNetworkImageProvider(pPic) // 🌟 Caching Image
                        : const CachedNetworkImageProvider(
                            'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                          ),
                  ),
                  title: Text(
                    uName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: showUnreadBadge
                          ? (isDark ? Colors.white : Colors.black)
                          : Colors.grey,
                      fontWeight: showUnreadBadge
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: Text(
                    timeago.format(msgTime, locale: 'en_short'),
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildNormalGroupsTab(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_rooms')
          .where('users', arrayContains: currentUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const Center(
            child: Text(
              'No Groups Joined Yet 👥',
              style: TextStyle(color: Colors.grey),
            ),
          );

        var groupDocs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return (data['isGroup'] == true) && (data['isCommunity'] != true);
        }).toList();

        if (groupDocs.isEmpty)
          return const Center(
            child: Text(
              'No Groups Joined Yet 👥',
              style: TextStyle(color: Colors.grey),
            ),
          );

        return ListView.builder(
          itemCount: groupDocs.length,
          itemBuilder: (context, index) {
            var gData = groupDocs[index].data() as Map<String, dynamic>;
            String gName = gData['groupName'] ?? 'Group Chat';
            String gPic = gData['groupPic'] ?? '';
            String lastMessage = gData['lastMessage'] ?? '';
            String chatRoomId = gData['chatRoomId'] ?? groupDocs[index].id;
            Timestamp? ts = gData['timestamp'] as Timestamp?;
            DateTime msgTime = ts != null ? ts.toDate() : DateTime.now();

            return ListTile(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupChatRoomScreen(
                    groupId: chatRoomId,
                    groupName: gName,
                    groupPic: gPic,
                  ),
                ),
              ),
              leading: CircleAvatar(
                radius: 24,
                backgroundImage: gPic.isNotEmpty
                    ? CachedNetworkImageProvider(gPic) // 🌟 Caching Group Image
                    : const CachedNetworkImageProvider(
                        'https://cdn-icons-png.flaticon.com/512/1256/1256073.png',
                      ),
              ),
              title: Text(
                gName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey),
              ),
              trailing: Text(
                timeago.format(msgTime, locale: 'en_short'),
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCommunitiesTab(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists)
          return const Center(child: CircularProgressIndicator());
        var userData = snapshot.data!.data() as Map<String, dynamic>;
        String villageName = userData['village'] ?? '';

        if (villageName.trim().isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                "Tanda/Village name not set in Profile! 🏜️",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          );
        }

        return Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade700, Colors.teal.shade500],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gite_rounded, color: Colors.white, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "$villageName Community 🏡",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: communityGroups.length,
                itemBuilder: (context, index) {
                  var group = communityGroups[index];
                  return Card(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    elevation: 0.2,
                    margin: const EdgeInsets.only(bottom: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: (group['color'] as Color).withAlpha(
                          38,
                        ),
                        child: Icon(
                          group['icon'],
                          color: group['color'],
                          size: 22,
                        ),
                      ),
                      title: Text(
                        group['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        group['desc'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey,
                        size: 20,
                      ),
                      onTap: () => _handleCommunityClick(villageName, group),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCallsTab(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_call,
            size: 50,
            color: Colors.blueAccent.withAlpha(50),
          ),
          const SizedBox(height: 14),
          const Text(
            "Banjara Voice & Video Calls",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            "Feature coming soon in Phase 3! 🚀",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
