import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/safe_elements.dart';
import 'post_details_screen.dart';
import 'other_user_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _q = "";
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🌟 FIXED: app_bar changed to appBar
      appBar: AppBar(
        title: TextField(
          onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          decoration: const InputDecoration(
            hintText: "Search users or bio...",
            border: InputBorder.none,
          ),
        ),
      ),
      body: _q.isEmpty
          ? StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                // 🌟 FIXED: Added curly braces for if block
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var posts = snapshot.data!.docs
                    .where((doc) => (doc.data() as Map)['isPrivate'] != true)
                    .toList();
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  itemCount: posts.length,
                  itemBuilder: (context, index) => GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PostDetailsScreen(postId: posts[index].id),
                      ),
                    ),
                    child: SafeImage(
                      base64String: (posts[index].data() as Map)['postData'],
                    ),
                  ),
                );
              },
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                // 🌟 FIXED: Added curly braces for if block
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var res = snapshot.data!.docs.where((doc) {
                  var d = doc.data() as Map<String, dynamic>;
                  return (d['username'] ?? "")
                          .toString()
                          .toLowerCase()
                          .contains(_q) ||
                      (d['bio'] ?? "").toString().toLowerCase().contains(_q);
                }).toList();
                return ListView.builder(
                  itemCount: res.length,
                  itemBuilder: (context, index) {
                    var u = res[index].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: SafeProfilePic(
                        base64String: u['profilePic'],
                        radius: 20,
                        fallbackText: u['username'] ?? "U",
                      ),
                      title: Text(u['username'] ?? ""),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              OtherUserProfileScreen(uid: u['uid']),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
