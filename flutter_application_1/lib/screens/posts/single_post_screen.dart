import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/post_widget.dart';

class SinglePostScreen extends StatelessWidget {
  final String postId;
  const SinglePostScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: const Text("Post"),
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 1,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text("ఈ పోస్ట్ డిలీట్ చేయబడింది లేదా కనిపించడం లేదు."),
            );
          }

          var postData = snapshot.data!.data() as Map<String, dynamic>;
          postData['postId'] = snapshot.data!.id;

          // 🌟 మనం ఆల్రెడీ రాసిన PostWidget ని ఇక్కడ వాడుకుంటున్నాం!
          return SingleChildScrollView(child: PostWidget(post: postData));
        },
      ),
    );
  }
}
