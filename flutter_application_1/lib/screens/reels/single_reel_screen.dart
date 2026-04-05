import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'scrolling_reels_screen.dart';

class SingleReelScreen extends StatelessWidget {
  final String reelId;
  const SingleReelScreen({super.key, required this.reelId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('reels')
            .doc(reelId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          if (!snapshot.data!.exists) {
            return const Center(
              child: Text(
                "Reel not found",
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return ScrollingReelsScreen(reelIds: [reelId]);
        },
      ),
    );
  }
}
