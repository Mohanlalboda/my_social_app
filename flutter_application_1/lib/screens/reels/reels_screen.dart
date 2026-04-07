import 'package:flutter/material.dart';
import 'scrolling_reels_screen.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});
  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  @override
  Widget build(BuildContext context) {
    // 🌟 ప్యాజినేషన్, రీల్స్ లాగడం అన్నీ ఈ ScrollingReelsScreen చూసుకుంటుంది!
    return const ScrollingReelsScreen();
  }
}
