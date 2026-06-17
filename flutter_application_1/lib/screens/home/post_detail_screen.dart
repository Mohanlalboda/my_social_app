// lib/screens/home/post_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 🌟 THE FIX: మనం ఇందాక home_screen.dart లో ఉన్న కార్డులనే ఇక్కడ వాడుతాం
import 'widgets/home_post_card.dart';
import 'widgets/home_reel_card.dart';

class PostDetailScreen extends StatelessWidget {
  final String postId;
  final String type; // 'post', 'reel', 'audio'

  const PostDetailScreen({super.key, required this.postId, required this.type});

  @override
  Widget build(BuildContext context) {
    // 🌟 టైప్ ని బట్టి ఏ కలెక్షన్ లో వెతకాలో డిసైడ్ చేస్తాం
    String collectionName = type == 'reel' ? 'reels' : 'posts';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection(collectionName)
                .doc(postId)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.blueAccent),
                );
              }

              // పోస్ట్ దొరకకపోతే (డిలీట్ అయిపోయి ఉంటే)
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(
                  child: Text(
                    "Sorry, this post is no longer available. 🏜️",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                );
              }

              var data = snapshot.data!.data() as Map<String, dynamic>;

              // 🌟 టైప్ ని బట్టి కరెక్ట్ కార్డుని (Home Screen లోనిదే) చూపిస్తాం
              if (type == 'reel') {
                return HomeReelCard(
                  reelData: data,
                  reelId: postId,
                  isActive:
                      true, // ఇక్కడ ఒక్కటే రీల్ ఉంది కాబట్టి ఎప్పుడూ ఆక్టివ్ గానే ఉండాలి
                );
              } else {
                return HomePostCard(
                  postData: data,
                  postId: postId,
                  isActive: true, // ఆడియో అయితే ఆటోమేటిక్ గా ప్లే అవ్వడానికి
                );
              }
            },
          ),

          // 🌟 పైన బ్యాక్ బటన్, డీప్ లింక్ నుంచి వచ్చిన వాళ్ళు వెనక్కి వెళ్ళడానికి
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(
                        context,
                      ); // యాప్ బ్యాక్ గ్రౌండ్ లో ఉంటే వెనక్కి వెళ్తుంది
                    } else {
                      // ఇక్కడ మీరు కావాలంటే హోమ్ స్క్రీన్ కి నావిగేట్ చేయొచ్చు
                      // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
