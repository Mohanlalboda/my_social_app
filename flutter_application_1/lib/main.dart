// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/reels_screen.dart';

// 🌟 థీమ్ కంట్రోలర్
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🌟 1. ముందు ఫైర్‌బేస్ స్టార్ట్ అవ్వాలి (ఇది ఇందాక మిస్ అయ్యింది)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 🌟 2. ఆ తర్వాత యాప్ చెక్ ఆన్ అవ్వాలి
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity, // పాత వెర్షన్స్ కోసం
  );

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
            brightness: Brightness.light,
            primaryColor: const Color(0xFFFD1D1D),
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0.5,
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Colors.white,
              selectedItemColor: Color(0xFFFD1D1D),
              unselectedItemColor: Colors.grey,
            ),
            textTheme: GoogleFonts.poppinsTextTheme(
              ThemeData.light().textTheme,
            ),
          ),

          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFFFD1D1D),
            scaffoldBackgroundColor: Colors.black,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0.5,
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Colors.black,
              selectedItemColor: Color(0xFFFD1D1D),
              unselectedItemColor: Colors.white54,
            ),
            textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
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

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(),
    const ReelsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: _selectedIndex == 2 || _selectedIndex == 3
          ? null
          : AppBar(
              title: Text(
                "MyBanjara",
                style: GoogleFonts.lobster(
                  fontSize: 28,
                  color: const Color(0xFFFD1D1D),
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    isDarkMode ? Icons.light_mode : Icons.dark_mode,
                    color: isDarkMode ? Colors.amber : Colors.black,
                  ),
                  onPressed: () {
                    themeNotifier.value = isDarkMode
                        ? ThemeMode.light
                        : ThemeMode.dark;
                  },
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('notifications')
                      .where('receiverId', isEqualTo: currentUser?.uid)
                      .where('isRead', isEqualTo: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    int unreadCount = snapshot.hasData
                        ? snapshot.data!.docs.length
                        : 0;
                    return Badge(
                      isLabelVisible: unreadCount > 0,
                      label: Text(unreadCount.toString()),
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
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('messages')
                      .where('receiverId', isEqualTo: currentUser?.uid)
                      .where('isRead', isEqualTo: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    int unreadCount = snapshot.hasData
                        ? snapshot.data!.docs.length
                        : 0;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Badge(
                        isLabelVisible: unreadCount > 0,
                        label: Text(unreadCount.toString()),
                        child: IconButton(
                          icon: Icon(
                            Icons.send_outlined,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const InboxScreen(),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
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
