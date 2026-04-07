// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'screens/create/add_post_screen.dart';
import 'services/notification_service.dart';
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

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Background Message Received: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await PushNotificationService.initialize();
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

// 🌟 THE FIX: WidgetsBindingObserver ని ఇక్కడ యాడ్ చేశాం
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(),
    const SizedBox(), // + బటన్ కోసం ప్లేస్‌హోల్డర్
    const ReelsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // 🌟 యాప్ ఓపెన్ చేయగానే ఆన్‌లైన్ లో ఉన్నట్టు ఫైర్‌బేస్ కి చెప్తాం
    _updateOnlineStatus(true);

    // 🌟 యాప్ ని మినిమైజ్ చేసినా, మళ్ళీ ఓపెన్ చేసినా పసిగట్టడానికి ఇది పెడతాం
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // 🌟 యాప్ పూర్తిగా క్లోజ్ చేసినప్పుడు అబ్జర్వర్ ని తీసేసి, ఆఫ్‌లైన్ అని చెప్తాం
    _updateOnlineStatus(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 🌟 యాప్ బ్యాక్‌గ్రౌండ్ కి వెళ్తే కనుక్కునే మ్యాజిక్ ఇక్కడే జరుగుతుంది
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // యూజర్ మళ్ళీ యాప్ లోకి వచ్చాడు (Online)
      _updateOnlineStatus(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      // యూజర్ వేరే యాప్ కి వెళ్ళాడు లేదా క్లోజ్ చేసాడు (Offline)
      _updateOnlineStatus(false);
    }
  }

  // 🌟 ఫైర్‌బేస్ లో స్టేటస్ అప్‌డేట్ చేసే ఫంక్షన్
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

    return Scaffold(
      appBar: _selectedIndex == 3 || _selectedIndex == 4
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
                  child: UnreadChatBadge(
                    child: IconButton(
                      icon: Icon(
                        Icons.send_outlined,
                        color: isDarkMode ? Colors.white : Colors.black,
                        size: 26,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const InboxScreen(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) {
          if (i == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddPostScreen()),
            );
          } else {
            setState(() => _selectedIndex = i);
          }
        },
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box_outlined, size: 30),
            label: "Add",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library_outlined),
            label: "Reels",
          ),
          BottomNavigationBarItem(
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
                right: 0,
                top: 5,
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
