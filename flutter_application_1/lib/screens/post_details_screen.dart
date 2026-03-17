// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/post_widget.dart';

class PostDetailsScreen extends StatelessWidget {
  final String postId;
  const PostDetailsScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Post", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
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
