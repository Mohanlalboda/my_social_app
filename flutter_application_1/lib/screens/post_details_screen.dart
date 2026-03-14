import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/post_widget.dart';

class PostDetailsScreen extends StatelessWidget {
  final String postId;
  const PostDetailsScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Post")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text("Post not found"));
          }

          return SingleChildScrollView(
            child: PostWidget(
              post: snapshot.data!.data() as Map<String, dynamic>,
            ),
          );
        },
      ),
    );
  }
}
