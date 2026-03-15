import 'dart:async'; // 🌟 టైమర్ వాడటానికి ఇది ముఖ్యం
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../widgets/safe_elements.dart';

class StoryScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const StoryScreen({super.key, required this.user});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  Timer? _storyTimer; // 🌟 5 సెకన్ల టైమర్ వేరియబుల్

  @override
  void initState() {
    super.initState();
    _markAsSeen();
    _startStoryTimer(); // 🌟 స్టోరీ ఓపెన్ అవ్వగానే టైమర్ స్టార్ట్ అవుతుంది
  }

  void _markAsSeen() async {
    String? storyId = widget.user['storyId'];
    String currentUid = FirebaseAuth.instance.currentUser!.uid;

    if (storyId != null) {
      await FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .update({
            'viewers': FieldValue.arrayUnion([currentUid]),
          })
          .catchError((e) => debugPrint("Error updating seen: $e"));
    }
  }

  // 🌟 5 సెకన్ల తర్వాత ఆటోమేటిక్ గా క్లోజ్ చేసే లాజిక్
  void _startStoryTimer() {
    _storyTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pop(context); // 5 సెకన్ల తర్వాత స్టోరీ క్లోజ్ అవుతుంది
      }
    });
  }

  @override
  void dispose() {
    _storyTimer
        ?.cancel(); // 🌟 ఒకవేళ యూజర్ ముందే క్లోజ్ చేసేస్తే టైమర్ ఆగిపోవాలి
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String timeStr = "";
    if (widget.user['timestamp'] != null) {
      timeStr = timeago.format(
        (widget.user['timestamp'] as Timestamp).toDate(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // స్టోరీ ఫోటో మధ్యలో కనిపిస్తుంది
            Center(child: SafeImage(base64String: widget.user['storyData'])),

            // పైన ప్రొఫైల్ పేరు, ఫోటో, టైమ్ మరియు X బటన్
            Positioned(
              top: 15,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  SafeProfilePic(
                    base64String: widget.user['profilePic'],
                    radius: 20,
                    fallbackText:
                        (widget.user['username'] != null &&
                            widget.user['username']
                                .toString()
                                .trim()
                                .isNotEmpty)
                        ? widget.user['username'][0].toUpperCase()
                        : "U",
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user['username'] ?? "User",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // 🌟 ముందే క్లోజ్ చేసుకోవడానికి X బటన్ (ఇది ఎప్పటిలాగే పనిచేస్తుంది)
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () {
                      _storyTimer
                          ?.cancel(); // X నొక్కితే టైమర్ ఆగిపోయి క్లోజ్ అవుతుంది
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
