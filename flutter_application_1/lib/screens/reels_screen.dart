import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/reel_item.dart';

class ReelsScreen extends StatelessWidget {
  const ReelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<QuerySnapshot>(
        // 🌟 ఇక్కడ orderBy తీసేసి డైరెక్ట్ గా వాడుతున్నాం
        stream: FirebaseFirestore.instance.collection('reels').snapshots(),
        builder: (context, snapshot) {
          // 🚨 డేటా రాకుండా ఫైర్‌బేస్ ఆపేస్తే, ఈ ఎర్రర్ స్క్రీన్ మీద కనిపిస్తుంది!
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  "🚨 Error: ${snapshot.error}",
                  style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No Reels yet! 🎬",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            );
          }

          var reels = snapshot.data!.docs;

          return PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: reels.length,
            itemBuilder: (context, index) {
              var reelData = reels[index].data() as Map<String, dynamic>;
              // 🌟 మ్యాజిక్ ఇక్కడ ఉంది: డాక్యుమెంట్ ఐడీని లాగుతున్నాం
              String reelId = reels[index].id;

              // 🌟 ఫిక్స్: ReelItem కి reel మరియు reelId పక్కాగా పంపుతున్నాం
              return ReelItem(reel: reelData, reelId: reelId);
            },
          );
        },
      ),
    );
  }
}
