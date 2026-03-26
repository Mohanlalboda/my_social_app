// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../widgets/safe_elements.dart';
import 'chat_screen.dart'; // కింద మనం చేయబోయే స్క్రీన్

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  // 🌟 కొత్త చాట్ కోసం ఫాలోవర్స్ ని చూపించే ఫంక్షన్ (WhatsApp Style Contacts)
  void _showFollowersToChat() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(15.0),
              child: Text(
                "Select Contact",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUid)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  List following =
                      (snapshot.data!.data()
                          as Map<String, dynamic>)['following'] ??
                      [];

                  if (following.isEmpty)
                    return const Center(
                      child: Text("You are not following anyone yet."),
                    );

                  return ListView.builder(
                    controller: controller,
                    itemCount: following.length,
                    itemBuilder: (context, index) {
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(following[index])
                            .get(),
                        builder: (context, userSnap) {
                          if (!userSnap.hasData || !userSnap.data!.exists)
                            return const SizedBox();
                          var userData =
                              userSnap.data!.data() as Map<String, dynamic>;

                          return ListTile(
                            leading: SafeProfilePic(
                              base64String: userData['profilePic'],
                              radius: 20,
                              fallbackText: userData['username'][0],
                            ),
                            title: Text(
                              userData['username'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(userData['bio'] ?? '', maxLines: 1),
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    receiverId: following[index],
                                    receiverName: userData['username'],
                                    receiverPic: userData['profilePic'],
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: const Text(
          "Chats",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? Colors.black : Colors.white,
      ),
      // 🌟 కొత్త చాట్ బటన్
      floatingActionButton: FloatingActionButton(
        onPressed: _showFollowersToChat,
        backgroundColor: const Color(0xFFFD1D1D),
        child: const Icon(Icons.message, color: Colors.white),
      ),
      // 🌟 లేటెస్ట్ మెసేజెస్ పైన వచ్చేలా StreamBuilder
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chatRooms')
            .where('users', arrayContains: currentUid)
            .orderBy('timestamp', descending: true) // లేటెస్ట్ వి పైన వస్తాయి
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Center(child: Text("Something went wrong"));
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());

          var chatRooms = snapshot.data!.docs;
          if (chatRooms.isEmpty)
            return const Center(
              child: Text(
                "No chats yet. Start a conversation! 💬",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );

          return ListView.builder(
            itemCount: chatRooms.length,
            itemBuilder: (context, index) {
              var roomData = chatRooms[index].data() as Map<String, dynamic>;
              List users = roomData['users'];
              String otherUserId = users.firstWhere((id) => id != currentUid);

              bool hasUnread = roomData['hasUnread_$currentUid'] ?? false;
              String lastMsg = roomData['lastMessage'] ?? '';
              DateTime time =
                  (roomData['timestamp'] as Timestamp?)?.toDate() ??
                  DateTime.now();

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherUserId)
                    .get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) return const SizedBox();
                  var userData =
                      userSnap.data!.data() as Map<String, dynamic>? ?? {};
                  String name = userData['username'] ?? 'User';
                  String pic = userData['profilePic'] ?? '';
                  bool isOnline = userData['isOnline'] ?? false;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 5,
                    ),
                    leading: Stack(
                      children: [
                        SafeProfilePic(
                          base64String: pic,
                          radius: 25,
                          fallbackText: name.isNotEmpty ? name[0] : 'U',
                        ),
                        // 🌟 ఆన్‌లైన్ గ్రీన్ డాట్
                        if (isOnline)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? Colors.black : Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontWeight: hasUnread
                            ? FontWeight.bold
                            : FontWeight.w600,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      roomData['typing_$otherUserId'] == true
                          ? "typing..."
                          : lastMsg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: roomData['typing_$otherUserId'] == true
                            ? Colors.green
                            : (hasUnread
                                  ? (isDark ? Colors.white : Colors.black)
                                  : Colors.grey),
                        fontStyle: roomData['typing_$otherUserId'] == true
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          timeago.format(time, locale: 'en_short'),
                          style: TextStyle(
                            color: hasUnread ? Colors.blue : Colors.grey,
                            fontSize: 12,
                            fontWeight: hasUnread
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 5),
                        if (hasUnread)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      // అన్‌రీడ్ మార్క్ తీసేయడం
                      FirebaseFirestore.instance
                          .collection('chatRooms')
                          .doc(chatRooms[index].id)
                          .update({'hasUnread_$currentUid': false});
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            receiverId: otherUserId,
                            receiverName: name,
                            receiverPic: pic,
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
      ),
    );
  }
}
