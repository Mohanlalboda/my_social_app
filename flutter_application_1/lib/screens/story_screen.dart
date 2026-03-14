import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/safe_elements.dart';

class StoryScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const StoryScreen({super.key, required this.user});
  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 5))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) Navigator.pop(context);
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('stories').where('ownerId', isEqualTo: widget.user['uid']).snapshots(),
        builder: (context, s) {
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          var stories = s.data!.docs.toList()
            ..sort((a, b) => (b.data() as Map)['timestamp'].compareTo((a.data() as Map)['timestamp']));
          
          String img = stories.isNotEmpty ? (stories.first.data() as Map)['storyData'] : "";
          
          return Stack(
            children: [
              Center(child: SafeImage(base64String: img, fit: BoxFit.contain)),
              Positioned(
                top: 40, left: 10, right: 10,
                child: LinearProgressIndicator(value: _c.value, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(Colors.white)),
              ),
              Positioned(
                top: 50, left: 15,
                child: Row(
                  children: [
                    SafeProfilePic(base64String: widget.user['profilePic'], radius: 18, fallbackText: widget.user['username']),
                    const SizedBox(width: 10),
                    Text(widget.user['username'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}