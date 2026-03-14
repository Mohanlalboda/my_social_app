import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

// 🌟 మీ కొత్త ఫైల్స్ అన్నింటినీ ఇక్కడ ఇంపోర్ట్ చేస్తున్నాం
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/inbox_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MySocialApp());
}

class MySocialApp extends StatelessWidget {
  const MySocialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MyBanjara',
      theme: ThemeData(
        primaryColor: const Color(0xFFFD1D1D),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
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
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  // main.dart లోని నేవిగేషన్ లిస్ట్
  final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(),
    const Center(child: Text("Reels coming soon!")),
    const ProfileScreen(), // 🌟 ఇక్కడ ఎర్రర్ రాకూడదు
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex == 3
          ? null
          : AppBar(
              elevation: 0.5,
              backgroundColor: Colors.white,
              title: Text(
                "MyBanjara",
                style: GoogleFonts.lobster(
                  fontSize: 28,
                  color: const Color(0xFFFD1D1D),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.favorite_border, color: Colors.black),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ActivityScreen(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_outlined, color: Colors.black),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const InboxScreen(),
                    ),
                  ),
                ),
              ],
            ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        selectedItemColor: const Color(0xFFFD1D1D),
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
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
