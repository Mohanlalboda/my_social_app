import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';

// 1. మెయిన్ ఎంట్రీ పాయింట్
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

// 2. మెయిన్ నావిగేషన్ (స్క్రీన్లను మార్చే బుర్ర)
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
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType
            .fixed, // 4 ఐకాన్లు ఉన్నప్పుడు ఇది వాడటం మంచిది
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library),
            label: "Reels",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

// --- 3. హోమ్ స్క్రీన్ (Stories + Feed) ---
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
      body: Column(
        children: [
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 10,
              itemBuilder: (context, index) => StoryWidget(index: index),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: 10,
              itemBuilder: (context, index) => PostWidget(index: index),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 4. సెర్చ్ స్క్రీన్ (Explore Grid) ---
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
        itemCount: 21,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemBuilder: (context, index) => Image.network(
          "https://picsum.photos/id/${index + 60}/300/300",
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

// --- 5. రీల్స్ స్క్రీన్ (Vertical Scroll) ---
class ReelsScreen extends StatelessWidget {
  const ReelsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: 5,
        itemBuilder: (context, index) {
          return Stack(
            children: [
              // ReelsScreen లోని Stack లోపల మొదటి ఐటమ్ గా ఇది పెట్టండి:
              SizedBox.expand(
                child: VideoReelItem(
                  videoUrl:
                      "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4",
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                  ),
                ),
              ),
              Positioned(
                right: 15,
                bottom: 100,
                child: Column(
                  children: [
                    const Icon(Icons.favorite, color: Colors.white, size: 35),
                    const Text("1.2k", style: TextStyle(color: Colors.white)),
                    const SizedBox(height: 20),
                    const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                      size: 35,
                    ),
                    const Text("45", style: TextStyle(color: Colors.white)),
                    const SizedBox(height: 20),
                    const Icon(Icons.send, color: Colors.white, size: 35),
                  ],
                ),
              ),
              Positioned(
                left: 15,
                bottom: 30,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "User_$index",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Learning Flutter for my Law Project! ⚖️🚀",
                      style: TextStyle(color: Colors.white),
                    ),
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

// --- 6. ప్రొఫైల్ స్క్రీన్ ---
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
                  child: ClipOval(
                    child: Image.network(
                      "https://ui-avatars.com/api/?name=Mohanlal&background=random&size=128",
                      fit: BoxFit.cover,
                      width: 80,
                      height: 80,
                    ),
                  ),
                ),
                const Column(
                  children: [
                    Text("12", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("Posts"),
                  ],
                ),
                const Column(
                  children: [
                    Text("450", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("Followers"),
                  ],
                ),
                const Column(
                  children: [
                    Text("300", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("Following"),
                  ],
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
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Icon(Icons.grid_on, color: Colors.black),
              Icon(Icons.video_collection_outlined, color: Colors.grey),
              Icon(Icons.person_pin_outlined, color: Colors.grey),
            ],
          ),
          const Divider(),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(1),
              itemCount: 12,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemBuilder: (context, index) {
                return Image.network(
                  "https://picsum.photos/id/${index + 80}/300/300",
                  fit: BoxFit.cover,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- 7. సహాయక విడ్జెట్లు (Post & Story) ---
class PostWidget extends StatefulWidget {
  final int index;
  const PostWidget({super.key, required this.index});
  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  bool isLiked = false;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        Image.network(
          "https://picsum.photos/id/${widget.index + 10}/500/500",
          height: 400,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? Colors.red : Colors.black,
              ),
              onPressed: () => setState(() => isLiked = !isLiked),
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
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.yellow,
                  Colors.orange,
                  Colors.red,
                  Colors.purple,
                ],
              ),
            ),
            child: CircleAvatar(
              radius: 35,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 32,
                backgroundImage: NetworkImage(
                  "https://picsum.photos/id/${index + 50}/100/100",
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text("User_$index", style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class VideoReelItem extends StatefulWidget {
  final String videoUrl;
  const VideoReelItem({super.key, required this.videoUrl});

  @override
  State<VideoReelItem> createState() => _VideoReelItemState();
}

class _VideoReelItemState extends State<VideoReelItem> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    // వీడియోను ఇంటర్నెట్ నుండి లోడ్ చేయడం
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {}); // వీడియో రెడీ అవ్వగానే స్క్రీన్‌ని రిఫ్రెష్ చేస్తుంది
        _controller.play(); // ఆటోమేటిక్‌గా ప్లే చేస్తుంది
        _controller.setLooping(true); // వీడియో మళ్ళీ మళ్ళీ వస్తుంది
      });
  }

  @override
  void dispose() {
    _controller
        .dispose(); // మెమరీ సేవ్ చేయడానికి వీడియో కంట్రోలర్‌ని క్లోజ్ చేస్తుంది
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          )
        : const Center(child: CircularProgressIndicator(color: Colors.white));
  }
}
