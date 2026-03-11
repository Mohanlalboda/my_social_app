import 'package:flutter/material.dart';

void main() => runApp(const MySocialApp());

class MySocialApp extends StatelessWidget {
  const MySocialApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainNavigation(),
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

  // మీ స్క్రీన్‌లను ఇక్కడ లిస్ట్ చేస్తున్నాం
  final List<Widget> _screens = [
    const HomeScreen(),   // ఫీడ్ పేజీ
    const Center(child: Text("Search Coming Soon...")), // సెర్చ్ ప్లేస్‌హోల్డర్
    const ProfileScreen(), // ప్రొఫైల్ పేజీ
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ఎంచుకున్న ఇండెక్స్ ప్రకారం స్క్రీన్ మారుతుంది
      body: _screens[_selectedIndex], 
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

// --- ఇక్కడ నుండి మీ హోమ్ స్క్రీన్ కోడ్ ---
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text("Instagram Clone",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.favorite_border, color: Colors.black), onPressed: () {}),
          IconButton(icon: const Icon(Icons.send_outlined, color: Colors.black), onPressed: () {}),
        ],
      ),
      body: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(10.0),
                child: Row(
                  children: [
                    CircleAvatar(backgroundColor: Colors.grey, radius: 18, child: Icon(Icons.person, color: Colors.white)),
                    SizedBox(width: 10),
                    Text("User_Name", style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Container(
                height: 400, width: double.infinity, color: Colors.grey[300],
                child: const Icon(Icons.image, size: 80, color: Colors.white),
              ),
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.chat_bubble_outline), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.send_outlined), onPressed: () {}),
                ],
              ),
              const Divider(),
            ],
          );
        },
      ),
    );
  }
}

// --- ఇక్కడ నుండి మీ ప్రొఫైల్ స్క్రీన్ కోడ్ ---
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white, elevation: 0,
        actions: [const Icon(Icons.menu, color: Colors.black), const SizedBox(width: 15)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const CircleAvatar(radius: 40, backgroundColor: Colors.blueAccent, child: Icon(Icons.person, size: 50, color: Colors.white)),
                Column(children: [const Text("10", style: TextStyle(fontWeight: FontWeight.bold)), const Text("Posts")]),
                Column(children: [const Text("500", style: TextStyle(fontWeight: FontWeight.bold)), const Text("Followers")]),
                Column(children: [const Text("300", style: TextStyle(fontWeight: FontWeight.bold)), const Text("Following")]),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Your Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text("Law Student | Osmania University ⚖️"),
                Text("Building the next viral social app! 🚀", style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () {}, child: const Text("Edit Profile"))),
          ),
          const Divider(height: 40),
          const Expanded(child: Center(child: Text("Your posts will appear here in a Grid!"))),
        ],
      ),
    );
  }
}