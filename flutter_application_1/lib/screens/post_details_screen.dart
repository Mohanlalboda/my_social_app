import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// 🌟 పాత PostWidget ని తీసేసి, మన కొత్త HomeScreen లోని PostCard ని వాడుతున్నాం
import 'home_screen.dart';

class PostDetailsScreen extends StatelessWidget {
  final String postId;
  const PostDetailsScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    // 🌟 కరెంట్ యూజర్ ఐడీని తీసుకుంటున్నాం
    final String currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor:
          Colors.white, // 🌟 బ్యాక్‌గ్రౌండ్ బ్లాక్ నుండి వైట్ కి మార్చాను
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
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text("Post not found"));
          }

          var postData = snapshot.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            // 🌟 మ్యాజిక్ ఇక్కడే: మనం ఉదయం ఫిక్స్ చేసిన పక్కా 'PostCard' ని వాడుతున్నాం!
            child: PostCard(
              post: postData,
              postId: postId,
              currentUid: currentUid,
            ),
          );
        },
      ),
    );
  }
}
