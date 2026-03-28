// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../widgets/safe_elements.dart';
import 'chat_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  // 🌟 కొత్త చాట్ స్టార్ట్ చేయడానికి ఫాలోవర్స్ లిస్ట్ చూపిస్తుంది
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

                  if (following.isEmpty) {
                    return const Center(
                      child: Text("You are not following anyone yet."),
                    );
                  }

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
                                    receiverName:
                                        userData['username'] ?? 'User',
                                    receiverPic: userData['profilePic'] ?? '',
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

  // 🌟 స్వైప్ చేసి చాట్ డిలీట్ చేసే ఫంక్షన్
  Future<void> _deleteChat(String chatRoomId) async {
    try {
      // చాట్ రూమ్ లో deletedBy అనే లిస్ట్ కి ఈ యూజర్ ఐడీ యాడ్ చేస్తున్నాం
      await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(chatRoomId)
          .set({
            'deletedBy': FieldValue.arrayUnion([currentUid]),
          }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Chat deleted from your inbox"),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint("Chat Delete Error: $e");
    }
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showFollowersToChat,
        backgroundColor: const Color(0xFFFD1D1D), // 🌟 బ్రాండ్ పింక్ కలర్
        child: const Icon(Icons.message, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chatRooms')
            .where('users', arrayContains: currentUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Center(child: Text("Something went wrong"));
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());

          var allChatRooms = snapshot.data!.docs;

          // 🌟 ఎవరైతే డిలీట్ చేయలేదో వాళ్ళకే చాట్ రూమ్ కనిపించాలి
          var visibleChatRooms = allChatRooms.where((room) {
            var roomData = room.data() as Map<String, dynamic>;
            List deletedBy = roomData['deletedBy'] ?? [];
            return !deletedBy.contains(currentUid);
          }).toList();

          if (visibleChatRooms.isEmpty) {
            return const Center(
              child: Text(
                "No chats yet. Start a conversation! 💬",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          // లేటెస్ట్ మెసేజెస్ పైన రావడానికి సార్టింగ్
          visibleChatRooms.sort((a, b) {
            var aData = a.data() as Map<String, dynamic>;
            var bData = b.data() as Map<String, dynamic>;
            Timestamp? t1 = aData['timestamp'] as Timestamp?;
            Timestamp? t2 = bData['timestamp'] as Timestamp?;
            if (t1 == null && t2 == null) return 0;
            if (t1 == null) return 1;
            if (t2 == null) return -1;
            return t2.compareTo(t1);
          });

          return ListView.builder(
            itemCount: visibleChatRooms.length,
            itemBuilder: (context, index) {
              var roomData =
                  visibleChatRooms[index].data() as Map<String, dynamic>;
              String roomId = visibleChatRooms[index].id;
              List users = roomData['users'];

              String otherUserId = users.firstWhere(
                (id) => id != currentUid,
                orElse: () => "",
              );
              if (otherUserId.isEmpty) return const SizedBox();

              int unreadCount = roomData['unread_$currentUid'] ?? 0;
              bool hasUnread = unreadCount > 0;
              String lastMsg = roomData['lastMessage'] ?? '';
              DateTime time =
                  (roomData['timestamp'] as Timestamp?)?.toDate() ??
                  DateTime.now();

              // 🌟 మ్యాజిక్ ఇక్కడే: Swipe to Delete విడ్జెట్
              return Dismissible(
                key: Key(roomId),
                direction:
                    DismissDirection.endToStart, // కుడి నుండి ఎడమకు స్వైప్
                onDismissed: (direction) => _deleteChat(roomId),
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
                child: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(otherUserId)
                      .get(),
                  builder: (context, userSnap) {
                    if (userSnap.connectionState == ConnectionState.waiting) {
                      return const ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey,
                          radius: 25,
                        ),
                        title: SizedBox(height: 15, width: 100),
                      );
                    }

                    if (!userSnap.hasData || !userSnap.data!.exists) {
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.grey,
                          radius: 25,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: const Text(
                          "Unknown User",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(lastMsg, maxLines: 1),
                      );
                    }

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
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                unreadCount > 9 ? "9+" : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      onTap: () {
                        FirebaseFirestore.instance
                            .collection('chatRooms')
                            .doc(roomId)
                            .update({'unread_$currentUid': 0});
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}
