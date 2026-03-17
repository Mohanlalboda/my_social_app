// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/reel_item.dart';

class SingleReelScreen extends StatelessWidget {
  final String reelId;
  const SingleReelScreen({super.key, required this.reelId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // 🌟 పైన యాప్ బార్ కింద నుండి వీడియో ప్లే అవ్వడానికి
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 30),
          onPressed: () => Navigator.pop(context), // బ్యాక్ వెళ్ళడానికి
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('reels')
            .doc(reelId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                "This Reel is unavailable or deleted. 🎬",
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          var reelData = snapshot.data!.data() as Map<String, dynamic>;

          // 🌟 ఫిక్స్: ReelItem కి reel మరియు reelId పక్కాగా పంపుతున్నాం
          return ReelItem(reel: reelData, reelId: reelId);
        },
      ),
    );
  }
}
