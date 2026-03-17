// ignore_for_file: curly_braces_in_flow_control_structures

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
        stream: FirebaseFirestore.instance.collection('reels').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(
              child: Text(
                "🚨 Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            );
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
            return const Center(
              child: Text(
                "No Reels yet! 🎬",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            );

          var reels = snapshot.data!.docs;

          return PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: reels.length,
            itemBuilder: (context, index) {
              var reelData = reels[index].data() as Map<String, dynamic>;
              String reelId = reels[index].id;
              return ReelItem(reel: reelData, reelId: reelId);
            },
          );
        },
      ),
    );
  }
}
