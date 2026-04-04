// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/post_widget.dart';

class PostDetailsScreen extends StatelessWidget {
  final String postId;
  const PostDetailsScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    // 🌟 ఫోన్ డార్క్ మోడ్‌లో ఉందా అని చెక్ చేస్తున్నాం
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // 🌟 బ్యాక్‌గ్రౌండ్ కలర్ తీసేశాం, ఆటోమేటిక్ గా బ్లాక్/వైట్ వస్తుంది
      appBar: AppBar(
        title: Text(
          "Post",
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        elevation: 0,
        backgroundColor: Colors.transparent, // 🌟 థీమ్ బట్టి అడ్జస్ట్ అవుతుంది
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.data!.exists)
            return const Center(child: Text("Post not found"));

          var postData = snapshot.data!.data() as Map<String, dynamic>;
          postData['postId'] = snapshot.data!.id;
          return PostWidget(post: postData);
        },
      ),
    );
  }
}
