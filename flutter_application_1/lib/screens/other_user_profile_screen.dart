// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/safe_elements.dart';
import 'post_details_screen.dart';
import 'chat_screen.dart';
import 'user_list_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
        if (!s.hasData)
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        // 🌟 యూజర్ డేటా ని 'u' అనే పేరుతో తీసుకుంటున్నాం
        var u = s.data!.data() as Map<String, dynamic>? ?? {};

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
                        var notifs = await FirebaseFirestore.instance
                            .collection('notifications')
                            .where('receiverId', isEqualTo: widget.uid)
                            .where('senderId', isEqualTo: myId)
                            .where('type', isEqualTo: 'follow')
                            .get();
                        for (var doc in notifs.docs)
                          await doc.reference.delete();
                      } else {
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
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          receiverId: widget.uid,
                          // 🌟 ఇక్కడ 'userData' బదులు పైన వాడిన 'u' వాడుతున్నాం
                          receiverName: u['username'] ?? 'User',
                          receiverPic: u['profilePic'] ?? '',
                        ),
                      ),
                    ),
                    // 🌟 బటన్ కి పేరు పెట్టాం!
                    child: const Text("Message"),
                  ),
                ],
              ),
              const Divider(),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('ownerId', isEqualTo: widget.uid)
                      .snapshots(),
                  builder: (context, ps) {
                    if (!ps.hasData)
                      return const Center(child: CircularProgressIndicator());
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
                        child: Builder(
                          builder: (context) {
                            var postMap =
                                posts[i].data() as Map<String, dynamic>;
                            var postData = postMap['postData'];
                            String thumbnail = "";

                            if (postData is List && postData.isNotEmpty) {
                              thumbnail = postData[0].toString();
                            } else {
                              thumbnail = postData?.toString() ?? "";
                            }

                            return thumbnail.startsWith('http')
                                ? CachedNetworkImage(
                                    imageUrl: thumbnail,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        Container(color: Colors.grey[200]),
                                    errorWidget: (context, url, error) =>
                                        const Icon(
                                          Icons.broken_image,
                                          color: Colors.grey,
                                        ),
                                  )
                                : SafeImage(base64String: thumbnail);
                          },
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
