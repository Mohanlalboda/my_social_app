import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago; // 🌟 టైమ్ ఫార్మాటింగ్ కోసం
import '../widgets/safe_elements.dart';
import 'post_details_screen.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();

  String getChatRoomId(String a, String b) {
    return a.hashCode <= b.hashCode ? "${a}_$b" : "${b}_$a";
  }

  @override
  Widget build(BuildContext context) {
    String currentUid = FirebaseAuth.instance.currentUser!.uid;
    String roomId = getChatRoomId(currentUid, widget.receiverId);

    // చాట్ ఓపెన్ చేయగానే అన్‌రీడ్ మెసేజ్ మార్క్ తీసేయడానికి
    FirebaseFirestore.instance.collection('chatRooms').doc(roomId).set({
      "hasUnread_$currentUid": false,
    }, SetOptions(merge: true));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.receiverName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chatRooms')
                  .doc(roomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var msgs = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  itemCount: msgs.length,
                  itemBuilder: (context, index) {
                    var m = msgs[index].data() as Map<String, dynamic>;
                    bool isMe = m['senderId'] == currentUid;

                    // 🌟 TIME FORMATTING LOGIC
                    String timeStr = "";
                    if (m['timestamp'] != null) {
                      DateTime date = (m['timestamp'] as Timestamp).toDate();
                      timeStr = timeago.format(date, locale: 'en_short');
                    }

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 10,
                            ),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.red[400] : Colors.grey[200],
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(15),
                                topRight: const Radius.circular(15),
                                bottomLeft: isMe
                                    ? const Radius.circular(15)
                                    : Radius.zero,
                                bottomRight: isMe
                                    ? Radius.zero
                                    : const Radius.circular(15),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (m['postImage'] != null) ...[
                                  GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PostDetailsScreen(
                                          postId: m['postId'],
                                        ),
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SafeImage(
                                        base64String: m['postImage'],
                                        height: 150,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                ],
                                Text(
                                  m['message'] ?? "",
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 🌟 DISPLAY TIMESTAMP BELOW BUBBLE
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 2,
                            ),
                            child: Text(
                              timeStr,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // మెసేజ్ పంపే బాక్స్
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: TextField(
                      controller: _msgController,
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.red,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: () async {
                      if (_msgController.text.trim().isEmpty) return;
                      String msg = _msgController.text.trim();
                      _msgController.clear();

                      await FirebaseFirestore.instance
                          .collection('chatRooms')
                          .doc(roomId)
                          .collection('messages')
                          .add({
                            "senderId": currentUid,
                            "message": msg,
                            "timestamp": FieldValue.serverTimestamp(),
                          });

                      await FirebaseFirestore.instance
                          .collection('chatRooms')
                          .doc(roomId)
                          .set({
                            "lastMessage": msg,
                            "lastTime": FieldValue.serverTimestamp(),
                            "users": [currentUid, widget.receiverId],
                            "hasUnread_${widget.receiverId}": true,
                          }, SetOptions(merge: true));
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
