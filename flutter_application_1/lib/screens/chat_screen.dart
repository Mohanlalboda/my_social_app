import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../widgets/safe_elements.dart';
import 'post_details_screen.dart';
import 'reels_screen.dart'; // 🌟 రీల్స్ ఓపెన్ చేయడానికి ఇది కావాలి

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
  final TextEditingController _messageController = TextEditingController();
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) {
      return;
    }

    String messageText = _messageController.text.trim();
    _messageController.clear();

    await FirebaseFirestore.instance.collection('messages').add({
      'senderId': currentUid,
      'receiverId': widget.receiverId,
      'text': messageText,
      'type': 'text',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    String roomId = currentUid.hashCode <= widget.receiverId.hashCode
        ? "${currentUid}_${widget.receiverId}"
        : "${widget.receiverId}_$currentUid";

    await FirebaseFirestore.instance.collection('chatRooms').doc(roomId).set({
      'users': [currentUid, widget.receiverId],
      'lastMessage': messageText,
      'timestamp': FieldValue.serverTimestamp(),
      'hasUnread_${widget.receiverId}': true,
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.receiverName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var unreadForMe = snapshot.data!.docs
                    .where(
                      (doc) =>
                          doc['receiverId'] == currentUid &&
                          doc['senderId'] == widget.receiverId &&
                          doc['isRead'] == false,
                    )
                    .toList();

                if (unreadForMe.isNotEmpty) {
                  Future.microtask(() {
                    WriteBatch batch = FirebaseFirestore.instance.batch();
                    for (var doc in unreadForMe) {
                      batch.update(doc.reference, {'isRead': true});
                    }
                    batch.commit();

                    String roomId =
                        currentUid.hashCode <= widget.receiverId.hashCode
                        ? "${currentUid}_${widget.receiverId}"
                        : "${widget.receiverId}_$currentUid";
                    FirebaseFirestore.instance
                        .collection('chatRooms')
                        .doc(roomId)
                        .update({'hasUnread_$currentUid': false})
                        .catchError((e) {});
                  });
                }

                var messages = snapshot.data!.docs.where((doc) {
                  return (doc['senderId'] == currentUid &&
                          doc['receiverId'] == widget.receiverId) ||
                      (doc['senderId'] == widget.receiverId &&
                          doc['receiverId'] == currentUid);
                }).toList();

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var msg = messages[index].data() as Map<String, dynamic>;
                    bool isMe = msg['senderId'] == currentUid;

                    String messageTime = "";
                    if (msg['timestamp'] != null) {
                      messageTime = timeago.format(
                        (msg['timestamp'] as Timestamp).toDate(),
                        locale: 'en_short',
                      );
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
                            margin: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2,
                            ),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            // 🌟 ఇక్కడే మ్యాజిక్: రీల్ అయితే ఈ డిజైన్ వస్తుంది
                            child: msg['type'] == 'reel'
                                ? SharedReelPreview(
                                    reelId: msg['reelId'],
                                    isMe: isMe,
                                  )
                                : msg['type'] == 'post_share'
                                ? SharedPostPreview(
                                    postId: msg['postId'],
                                    isMe: isMe,
                                  )
                                : Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? Colors.blue
                                          : Colors.grey[300],
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Text(
                                      msg['text'] ?? "",
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 2,
                            ),
                            child: Text(
                              messageTime,
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
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
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

// ----------------------------------------------------
// 🌟 కొత్తగా యాడ్ చేసిన REEL PREVIEW విడ్జెట్
// ----------------------------------------------------
class SharedReelPreview extends StatelessWidget {
  final String reelId;
  final bool isMe;
  const SharedReelPreview({
    super.key,
    required this.reelId,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reels')
          .doc(reelId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              "Reel Unavailable",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        var reelData = snapshot.data!.data() as Map<String, dynamic>;

        return GestureDetector(
          onTap: () {
            // 🌟 దీనిపై క్లిక్ చేస్తే ఒరిజినల్ రీల్స్ స్క్రీన్ ఓపెన్ అవుతుంది
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const ReelsScreen(), // లేదా ఒక సింగిల్ రీల్ పేజీ అయినా పెట్టుకోవచ్చు
              ),
            );
          },
          child: Container(
            width: 200,
            decoration: BoxDecoration(
              color: isMe ? Colors.blue[50] : Colors.grey[200],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.video_library,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          "Shared a Reel by ${reelData['username'] ?? 'User'}",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // 🌟 ఇక్కడ రీల్ కి సంబంధించిన ఒక చిన్న బ్లాక్ బాక్స్ ప్లే ఐకాన్ తో చూపిస్తున్నాం
                Container(
                  height: 250,
                  width: double.infinity,
                  color: Colors.black,
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
                if (reelData['caption'] != null &&
                    reelData['caption'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      reelData['caption'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// పాత పోస్ట్ ప్రివ్యూ విడ్జెట్
class SharedPostPreview extends StatelessWidget {
  final String postId;
  final bool isMe;
  const SharedPostPreview({
    super.key,
    required this.postId,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              "Post Unavailable",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        var postData = snapshot.data!.data() as Map<String, dynamic>;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PostDetailsScreen(postId: postId),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: isMe ? Colors.blue[50] : Colors.grey[200],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.post_add, size: 16, color: Colors.grey),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          "Shared a post by ${postData['username']}",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SafeImage(base64String: postData['postData']),
                ),
                if (postData['caption'] != null &&
                    postData['caption'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      postData['caption'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
