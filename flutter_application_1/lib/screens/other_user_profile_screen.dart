import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/safe_elements.dart';
import 'post_details_screen.dart';
import 'chat_screen.dart';
import 'user_list_screen.dart'; // 🌟 లిస్ట్ చూడటానికి ఇది కావాలి

class OtherUserProfileScreen extends StatefulWidget {
  final String uid;
  const OtherUserProfileScreen({super.key, required this.uid});
  @override
  State<OtherUserProfileScreen> createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen> {
  @override
  Widget build(BuildContext context) {
    String myId = FirebaseAuth.instance.currentUser!.uid;
    String myEmail = FirebaseAuth.instance.currentUser!.email!;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .snapshots(),
      builder: (context, s) {
        if (!s.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        var u = s.data!.data() as Map<String, dynamic>;

        List followers = u['followers'] ?? [];
        List following = u['following'] ?? [];
        bool isF = followers.contains(myId);

        return Scaffold(
          appBar: AppBar(title: Text(u['username'] ?? "Profile")),
          body: Column(
            children: [
              const SizedBox(height: 20),
              SafeProfilePic(
                base64String: u['profilePic'],
                radius: 50,
                fallbackText: u['username'] ?? "U",
              ),
              const SizedBox(height: 10),
              Text(
                u['username'] ?? "",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(u['bio'] ?? "No bio yet."),
              const SizedBox(height: 10),

              // 🌟 Followers & Following Count Section 🌟
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .where('ownerId', isEqualTo: widget.uid)
                    .snapshots(),
                builder: (context, postSnapshot) {
                  int postCount = postSnapshot.hasData
                      ? postSnapshot.data!.docs.length
                      : 0;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatColumn(num: postCount.toString(), label: "Posts"),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserListScreen(
                              title: "Followers",
                              userIds: followers,
                            ),
                          ),
                        ),
                        child: _StatColumn(
                          num: followers.length.toString(),
                          label: "Followers",
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserListScreen(
                              title: "Following",
                              userIds: following,
                            ),
                          ),
                        ),
                        child: _StatColumn(
                          num: following.length.toString(),
                          label: "Following",
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // 🌟 Follow & Message Buttons 🌟
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isF ? Colors.grey[300] : Colors.red,
                      foregroundColor: isF ? Colors.black : Colors.white,
                    ),
                    onPressed: () async {
                      if (isF) {
                        // UNFOLLOW LOGIC
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.uid)
                            .update({
                              'followers': FieldValue.arrayRemove([myId]),
                            });
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(myId)
                            .update({
                              'following': FieldValue.arrayRemove([widget.uid]),
                            });

                        // Delete Notification
                        var notifs = await FirebaseFirestore.instance
                            .collection('notifications')
                            .where('receiverId', isEqualTo: widget.uid)
                            .where('senderId', isEqualTo: myId)
                            .where('type', isEqualTo: 'follow')
                            .get();
                        for (var doc in notifs.docs) {
                          await doc.reference.delete();
                        }
                      } else {
                        // FOLLOW LOGIC
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.uid)
                            .update({
                              'followers': FieldValue.arrayUnion([myId]),
                            });
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(myId)
                            .update({
                              'following': FieldValue.arrayUnion([widget.uid]),
                            });

                        // Send Notification
                        await FirebaseFirestore.instance
                            .collection('notifications')
                            .add({
                              "receiverId": widget.uid,
                              "senderId": myId,
                              "senderName": myEmail.split('@')[0],
                              "type": "follow",
                              "timestamp": FieldValue.serverTimestamp(),
                              "isRead": false,
                            });
                      }
                    },
                    child: Text(isF ? "Unfollow" : "Follow"),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            receiverId: widget.uid,
                            receiverName: u['username'] ?? "User",
                          ),
                        ),
                      );
                    },
                    child: const Text("Message"),
                  ),
                ],
              ),
              const Divider(),

              // 🌟 Posts Grid 🌟
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('ownerId', isEqualTo: widget.uid)
                      .snapshots(),
                  builder: (context, ps) {
                    if (!ps.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    var posts = ps.data!.docs;
                    return GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                          ),
                      itemCount: posts.length,
                      itemBuilder: (context, i) => GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PostDetailsScreen(postId: posts[i].id),
                          ),
                        ),
                        child: SafeImage(
                          base64String: (posts[i].data() as Map)['postData'],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// 🌟 Widget for displaying stats like Posts, Followers, Following
class _StatColumn extends StatelessWidget {
  final String num;
  final String label;
  const _StatColumn({required this.num, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          num,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
