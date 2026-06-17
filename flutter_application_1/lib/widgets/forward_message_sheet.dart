// lib/widgets/forward_message_sheet.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_methods.dart'; // 🌟 బగ్ ఫిక్స్: ఇక్కడ రిలేటివ్ పాత్ సెట్ చేయబడింది బాస్!

class ForwardMessageSheet extends StatefulWidget {
  final String messageText;
  final String messageType;

  const ForwardMessageSheet({
    super.key,
    required this.messageText,
    required this.messageType,
  });

  @override
  State<ForwardMessageSheet> createState() => _ForwardMessageSheetState();
}

class _ForwardMessageSheetState extends State<ForwardMessageSheet> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  final Map<String, bool> _forwardedStatus = {};

  void _forwardMessage(String roomId, bool isGroup, String receiverId) async {
    setState(() => _forwardedStatus[roomId] = true);

    if (isGroup) {
      await FirestoreMethods().sendGroupMessage(roomId, widget.messageText);
    } else {
      await FirestoreMethods().sendMessage(receiverId, widget.messageText);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Message Forwarded! ➡️"),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'Forward Message To ➡️',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .where('users', arrayContains: currentUid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var rooms = snapshot.data!.docs;

                if (rooms.isEmpty) {
                  return const Center(
                    child: Text(
                      'No active chats to forward.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    var roomData = rooms[index].data() as Map<String, dynamic>;
                    String roomId = rooms[index].id;
                    bool isGroup = roomData['isGroup'] == true;

                    if (isGroup) {
                      String groupName = roomData['groupName'] ?? 'Group';
                      String groupPic = roomData['groupPic'] ?? '';
                      bool isSent = _forwardedStatus[roomId] == true;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: CachedNetworkImageProvider(
                            groupPic.isNotEmpty
                                ? groupPic
                                : 'https://cdn-icons-png.flaticon.com/512/1256/1256073.png',
                          ),
                        ),
                        title: Text(
                          groupName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        subtitle: const Text(
                          'Group Chat 👥',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        trailing: ElevatedButton(
                          onPressed: isSent
                              ? null
                              : () => _forwardMessage(roomId, true, ''),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSent
                                ? Colors.grey
                                : Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: Text(
                            isSent ? 'Sent ✓' : 'Send',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    } else {
                      List users = roomData['users'] ?? [];
                      String otherUid = users
                          .firstWhere(
                            (id) => id != currentUid,
                            orElse: () => '',
                          )
                          .toString();

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(otherUid)
                            .get(),
                        builder: (context, userSnap) {
                          if (!userSnap.hasData || !userSnap.data!.exists) {
                            return const SizedBox.shrink();
                          }
                          var userData =
                              userSnap.data!.data() as Map<String, dynamic>;
                          String username = userData['username'] ?? 'User';
                          String profilePic = userData['profilePic'] ?? '';
                          bool isSent = _forwardedStatus[roomId] == true;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: CachedNetworkImageProvider(
                                profilePic.isNotEmpty
                                    ? profilePic
                                    : 'https://cdn.pixabay.com/photo/...',
                              ),
                            ),
                            title: Text(
                              username,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            subtitle: const Text(
                              'Personal Chat 💬',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            trailing: ElevatedButton(
                              onPressed: isSent
                                  ? null
                                  : () => _forwardMessage(
                                      roomId,
                                      false,
                                      otherUid,
                                    ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSent
                                    ? Colors.grey
                                    : Colors.blueAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                              ),
                              child: Text(
                                isSent ? 'Sent ✓' : 'Send',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
