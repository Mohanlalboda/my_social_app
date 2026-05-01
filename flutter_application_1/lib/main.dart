// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // 🌟 యాడ్స్ కోసం
import 'dart:async'; // 🌟 కాల్ సబ్‌స్క్రిప్షన్ కోసం

import 'screens/chat/incoming_call_screen.dart'; // 🌟 కాల్ వస్తే ఈ స్క్రీన్ ఓపెన్ అవుతుంది
import 'screens/create/add_post_screen.dart';
import 'services/notification_service.dart';
import 'services/social_service.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/near_me_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/activity/activity_screen.dart';
import 'screens/chat/inbox_screen.dart';
import 'screens/reels/reels_screen.dart';
import 'utils/constants.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

// 🌟 వాట్సాప్ లాగా యాప్ క్లోజ్ లో ఉన్నప్పుడు పుష్ నోటిఫికేషన్స్ కోసం
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Background Message Received: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 🌟 యాడ్స్ ని ముందుగానే స్టార్ట్ చేయడం
  await MobileAds.instance.initialize();

  // 🌟 పుష్ నోటిఫికేషన్స్ సెటప్
  await PushNotificationService.initialize();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MySocialApp());
}

class MySocialApp extends StatelessWidget {
  const MySocialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, ThemeMode currentMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'MyBanjara',

          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            primaryColor: const Color(0xFF00E5FF),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF7A00FF),
              primary: const Color(0xFF00E5FF),
            ),
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
            ),
            progressIndicatorTheme: const ProgressIndicatorThemeData(
              color: Color(0xFF00E5FF),
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Colors.white,
              selectedItemColor: Color(0xFF7A00FF),
              unselectedItemColor: Colors.grey,
            ),
            textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
          ),

          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF00E5FF),
            colorScheme: ColorScheme.fromSeed(
              brightness: Brightness.dark,
              seedColor: const Color(0xFF7A00FF),
              primary: const Color(0xFF00E5FF),
            ),
            scaffoldBackgroundColor: brandDarkBackground,
            appBarTheme: const AppBarTheme(
              backgroundColor: brandDarkBackground,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            progressIndicatorTheme: const ProgressIndicatorThemeData(
              color: Color(0xFF00E5FF),
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: brandDarkBackground,
              selectedItemColor: Color(0xFF00E5FF),
              unselectedItemColor: Colors.white54,
            ),
            textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
            cardColor: Colors.grey[900],
          ),

          themeMode: currentMode,
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasData) {
                return const MainNavigation();
              }
              return const LoginScreen();
            },
          ),
        );
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;

  late PageController _pageController;
  StreamSubscription? _callSubscription; // 🌟 కాల్స్ గమనించడానికి

  final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(),
    const InboxScreen(),
    const ReelsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);

    _updateOnlineStatus(true);
    WidgetsBinding.instance.addObserver(this);
    SocialService.cleanupOldMoments();

    // 🌟 యాప్ ఓపెన్ చేయగానే ఎవరైనా కాల్ చేస్తున్నారేమో అని చెక్ చేస్తుంది
    _listenForIncomingCalls();
  }

  // 🌟 THE FIX: ఇక్కడే కాల్స్ కోసం ఫైర్‌బేస్ ని వింటుంటాం
 // 🌟 THE FIX: ఇక్కడే కాల్స్ కోసం ఫైర్‌బేస్ ని వింటుంటాం
  void _listenForIncomingCalls() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    _callSubscription = FirebaseFirestore.instance
        .collection('calls')
        .where('receiverId', isEqualTo: currentUid)
        .where('status', isEqualTo: 'ringing') // రింగ్ అవుతుంటేనే..
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        var callDoc = snapshot.docs.first;
        var callData = callDoc.data();
        
        // 🌟 THE FIX: ఎర్రర్ రాకుండా mounted చెక్ యాడ్ చేసాం
        if (!mounted) return;

        // వెంటనే ఇన్-కమింగ్ కాల్ స్క్రీన్ ఓపెన్ చేస్తుంది!
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IncomingCallScreen(
              callId: callDoc.id,
              callerName: callData['callerName'] ?? 'Someone',
              callerPic: callData['callerPic'] ?? '',
              isVideoCall: callData['isVideoCall'] ?? false,
              channelId: callData['channelId'] ?? callDoc.id,
            ),
          ),
        );
      }
    });
  }
  @override
  void dispose() {
    _callSubscription
        ?.cancel(); // 🌟 యాప్ క్లోజ్ చేసినప్పుడు ఇది కూడా ఆగిపోవాలి
    _pageController.dispose();
    _updateOnlineStatus(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateOnlineStatus(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      _updateOnlineStatus(false);
    }
  }

  void _updateOnlineStatus(bool isOnline) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({
              'isOnline': isOnline,
              'lastSeen': FieldValue.serverTimestamp(),
            });
      } catch (e) {
        debugPrint("Error updating online status: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    bool hideAppBar = _selectedIndex >= 2;

    return Scaffold(
      appBar: hideAppBar
          ? null
          : AppBar(
              title: ShaderMask(
                shaderCallback: (bounds) => brandGradient.createShader(
                  Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                ),
                child: Text(
                  "MyBanjara",
                  style: GoogleFonts.pacifico(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
              actions: [
                if (currentUser != null)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .collection('notifications')
                        .where('isRead', isEqualTo: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      int unreadCount = snapshot.hasData
                          ? snapshot.data!.docs.length
                          : 0;

                      return Badge(
                        isLabelVisible: unreadCount > 0,
                        label: Text(
                          unreadCount > 9 ? '9+' : unreadCount.toString(),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.favorite_border,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ActivityScreen(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(width: 5),
                IconButton(
                  icon: Icon(
                    Icons.radar,
                    color: isDarkMode ? Colors.white : Colors.black,
                    size: 28,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NearMeScreen()),
                    );
                  },
                ),
                const SizedBox(width: 5),
                Padding(
                  padding: const EdgeInsets.only(right: 15),
                  child: IconButton(
                    icon: Icon(
                      Icons.add_box_outlined,
                      color: isDarkMode ? Colors.white : Colors.black,
                      size: 28,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddPostScreen(),
                      ),
                    ),
                  ),
                ),
              ],
            ),

      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _screens,
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) {
          _pageController.animateToPage(
            i,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: "Home",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: "Search",
          ),
          const BottomNavigationBarItem(
            icon: UnreadChatBadge(child: Icon(Icons.send_outlined, size: 28)),
            label: "Messages",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.video_library_outlined),
            label: "Reels",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}

class UnreadChatBadge extends StatelessWidget {
  final Widget child;
  const UnreadChatBadge({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return child;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chatRooms')
          .where('users', arrayContains: currentUid)
          .snapshots(),
      builder: (context, snapshot) {
        int totalUnread = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            totalUnread += (data['unread_$currentUid'] as int?) ?? 0;
          }
        }

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            child,
            if (totalUnread > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF007F),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    totalUnread > 9 ? '9+' : totalUnread.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
