// lib/screens/main_screen.dart

import 'package:flutter/material.dart';
import 'home/home_screen.dart';
import 'search/banjara_radar_screen.dart';
import 'chat/direct_inbox_screen.dart';
import 'profile/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_methods.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _page = 0;
  late PageController pageController;

  @override
  void initState() {
    super.initState();
    pageController = PageController();

    WidgetsBinding.instance.addObserver(this);
    FirestoreMethods().updateActiveStatus(true);
    _saveFCMToken();
  }

  void _saveFCMToken() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // 1. నోటిఫికేషన్స్ కోసం పర్మిషన్ అడుగుతాం (Android 13+ మరియు iOS కి ముఖ్యం)
      await messaging.requestPermission();

      // 2. ఫోన్ యొక్క FCM టోకెన్ తెచ్చుకుంటాం
      String? token = await messaging.getToken();

      if (token != null) {
        String uid = FirebaseAuth.instance.currentUser!.uid;

        // 3. ఆ టోకెన్ ని Firestore లోని యూజర్ డేటాలో సేవ్ చేస్తాం
        await FirebaseFirestore.instance.collection('users').doc(uid).set(
          {'fcmToken': token},
          SetOptions(merge: true),
        ); // merge: true వాడితే పాత డేటా చెరిగిపోదు, ఇది మాత్రమే యాడ్ అవుతుంది

        debugPrint("🌟 FCM Token Saved Successfully: $token");
      }

      // 4. ఒకవేళ టోకెన్ ఎప్పుడైనా మారితే (యాప్ రీ-ఇన్స్టాల్ చేసినప్పుడు), ఆటోమేటిక్ గా అప్‌డేట్ అవ్వడానికి:
      messaging.onTokenRefresh.listen((newToken) async {
        String uid = FirebaseAuth.instance.currentUser!.uid;
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'fcmToken': newToken,
        }, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint("🚨 Error saving FCM token: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      FirestoreMethods().updateActiveStatus(true);
    } else {
      FirestoreMethods().updateActiveStatus(false);
    }
  }

  void navigationTapped(int page) {
    pageController.jumpToPage(page);
  }

  void onPageChanged(int page) {
    setState(() {
      _page = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: PageView(
        controller: pageController,
        onPageChanged: onPageChanged,
        // 🌟 THE FIX: ఇక్కడ physics ని తీసేసాం, కాబట్టి ఇప్పుడు Swipe చేస్తే నెక్స్ట్ స్క్రీన్ కి వెళ్తుంది!
        children: const [
          HomeScreen(),
          BanjaraRadarScreen(),
          DirectInboxScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        selectedItemColor: isDark ? Colors.white : Colors.black,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        currentIndex: _page,
        onTap: navigationTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.radar_rounded),
            activeIcon: Icon(Icons.radar),
            label: 'Radar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.messenger_outline_rounded),
            activeIcon: Icon(Icons.messenger_rounded),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
