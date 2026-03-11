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
    const HomeScreen(), // ఫీడ్ పేజీ
    const SearchScreen(), // సెర్చ్ ప్లేస్‌హోల్డర్
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
        title: const Text(
          "Instagram Clone",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.send_outlined, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      // HomeScreen లోని body ని ఇలా మార్చండి
      body: Column(
        children: [
          // 1. అడ్డంగా స్క్రోల్ అయ్యే స్టోరీస్ (Horizontal Stories)
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection:
                  Axis.horizontal, // ఇది అడ్డంగా స్క్రోల్ అయ్యేలా చేస్తుంది
              itemCount: 10,
              itemBuilder: (context, index) {
                return StoryWidget(index: index);
              },
            ),
          ),

          const Divider(height: 1), // స్టోరీస్ కి ఫీడ్ కి మధ్య ఒక చిన్న గీత
          // 2. నిలువుగా స్క్రోల్ అయ్యే పోస్ట్ ఫీడ్ (Vertical Feed)
          Expanded(
            child: ListView.builder(
              itemCount: 10,
              itemBuilder: (context, index) {
                return PostWidget(index: index);
              },
            ),
          ),
        ],
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
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          const Icon(Icons.menu, color: Colors.black),
          const SizedBox(width: 15),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey[200],
                  // ClipOval వాడితే లోపల వచ్చే ఫోటో కరెక్ట్ గా రౌండ్ గా మారుతుంది
                  child: ClipOval(
                    child: Image.network(
                      "https://ui-avatars.com/api/?name=Lal&background=random&size=128",
                      fit: BoxFit.cover,
                      width: 80,
                      height: 80,
                      // ఒకవేళ ఇంటర్నెట్ సరిగ్గా లేకపోతే ఈ కింద ఐకాన్ కనిపిస్తుంది
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.person, size: 50),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Mohanlal",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text("Law Student | Osmania University ⚖️"),
                Text(
                  "Building the next viral social app! 🚀",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                child: const Text("Edit Profile"),
              ),
            ),
          ),
          const Divider(height: 40),
          const Expanded(
            child: Center(
              child: Text("Your posts will appear here in a Grid!"),
            ),
          ),
        ],
      ),
    );
  }
}

class PostWidget extends StatefulWidget {
  final int index;
  const PostWidget({super.key, required this.index});

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  bool isLiked = false; // ఇది లైక్ అయిందా లేదా అని గుర్తుంచుకుంటుంది

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. యూజర్ హెడర్
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey[300],
                backgroundImage: NetworkImage(
                  "https://picsum.photos/id/${widget.index + 20}/50/50",
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "User_${widget.index}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        // 2. మెయిన్ ఫోటో
        Image.network(
          "https://picsum.photos/id/${widget.index + 10}/500/500",
          height: 400,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
        // 3. లైక్ బటన్ లాజిక్
        Row(
          children: [
            IconButton(
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? Colors.red : Colors.black,
              ),
              onPressed: () {
                // ఇక్కడ మ్యాజిక్ జరుగుతుంది!
                setState(() {
                  isLiked =
                      !isLiked; // false ఉంటే true, true ఉంటే false చేస్తుంది
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () {},
            ),
            IconButton(icon: const Icon(Icons.send_outlined), onPressed: () {}),
          ],
        ),
        const Divider(),
      ],
    );
  }
}

class StoryWidget extends StatelessWidget {
  final int index;
  const StoryWidget({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      child: Column(
        children: [
          // స్టోరీ చుట్టూ కలర్ బోర్డర్ కోసం ఒక Container
          Container(
            padding: const EdgeInsets.all(3), // బోర్డర్ మందం
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.yellow,
                  Colors.orange,
                  Colors.red,
                  Colors.purple,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: CircleAvatar(
                radius: 35,
                backgroundImage: NetworkImage(
                  "https://picsum.photos/id/${index + 50}/100/100",
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text("User_${index}", style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: const TextField(
            decoration: InputDecoration(
              hintText: "Search",
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(top: 5),
            ),
          ),
        ),
      ),
      body: GridView.builder(
        itemCount: 30, // 30 ఫోటోలు చూపిద్దాం
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, // ఒక వరుసలో 3 ఫోటోలు
          crossAxisSpacing: 2, // ఫోటోల మధ్య అడ్డంగా గ్యాప్
          mainAxisSpacing: 2, // ఫోటోల మధ్య నిలువుగా గ్యాప్
        ),
        itemBuilder: (context, index) {
          return Image.network(
            "https://picsum.photos/id/${index + 60}/300/300",
            fit: BoxFit.cover,
          );
        },
      ),
    );
  }
}
