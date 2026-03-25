// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/reel_item.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<QuerySnapshot>(
        // 🌟 లేటెస్ట్ రీల్స్ ముందు రావడానికి 'orderBy' యాడ్ చేశాను
        stream: FirebaseFirestore.instance
            .collection('reels')
            .orderBy('timestamp', descending: true)
            .snapshots(),
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
            controller: _pageController,
            scrollDirection: Axis.vertical,
            // 🚀 TRICK: ఇది ట్రూ (true) ఉంటే, కింద ఉన్న వీడియో మీరు చూడకముందే బ్యాక్‌గ్రౌండ్ లో ఫాస్ట్ గా డౌన్‌లోడ్ అయిపోతుంది!
            allowImplicitScrolling: true,
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
