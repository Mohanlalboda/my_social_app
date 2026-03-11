import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';

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

// 2. మెయిన్ నావిగేషన్ (Bottom Nav Logic)
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
        type: BottomNavigationBarType.fixed,
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

// --- 3. హోమ్ స్క్రీన్ (Stories + Feed + Add Post) ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// HomeScreen క్లాస్ లోపల ఈ మార్పులు చేయండి
class _HomeScreenState extends State<HomeScreen> {
  // కొత్త పోస్ట్‌లను స్టోర్ చేయడానికి ఒక లిస్ట్
  List<File> myPosts = [];

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        // సెలెక్ట్ చేసిన ఫోటోను మన లిస్ట్‌లో యాడ్ చేస్తున్నాం
        myPosts.insert(0, File(image.path));
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post Added Successfully! 🚀")),
      );
    }
  }

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
            icon: const Icon(
              Icons.add_box_outlined,
              color: Colors.black,
              size: 28,
            ),
            onPressed: _pickImage,
          ),
          // మిగిలిన ఐకాన్స్...
        ],
      ),
      body: Column(
        children: [
          // 1. Stories Section (యధావిధిగా ఉంటుంది)
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 10,
              itemBuilder: (context, index) => StoryWidget(index: index),
            ),
          ),
          const Divider(height: 1),

          // 2. Main Feed Section
          Expanded(
            child: ListView(
              children: [
                // మనం కొత్తగా యాడ్ చేసిన పోస్ట్‌లు ఇక్కడ కనిపిస్తాయి
                ...myPosts
                    .map(
                      (file) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ListTile(
                            leading: CircleAvatar(backgroundColor: Colors.blue),
                            title: Text(
                              "Mohanlal (You)",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Image.file(
                            file,
                            height: 400,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.favorite_border),
                          ),
                          const Divider(),
                        ],
                      ),
                    )
                    .toList(),

                // పాత డమ్మీ పోస్ట్‌లు (ListView.builder లాగా)
                ...List.generate(10, (index) => PostWidget(index: index)),
              ],
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

// --- 5. రీల్స్ స్క్రీన్ (Vertical Scroll Video) ---
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
              SizedBox.expand(
                child: VideoReelItem(
                  videoUrl:
                      "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4",
                ),
              ),
              // నిన్నటి పాత కోడ్‌లోని గ్రేడియంట్ మరియు ఐకాన్స్ ఇక్కడ యధావిధిగా ఉంటాయి...
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

// --- 6. ప్రొఫైల్ స్క్రీన్ (Edit Profile Logic) ---
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String name = "Mohanlal";
  final TextEditingController _nameController = TextEditingController();

  void _editProfile() {
    _nameController.text = name;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Edit Name",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            TextField(controller: _nameController),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: () {
                setState(() => name = _nameController.text);
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

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
                      "https://ui-avatars.com/api/?name=$name&background=random",
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
              ],
            ),
          ),
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const Text("Law Student | Osmania University ⚖️"),
          OutlinedButton(
            onPressed: _editProfile,
            child: const Text("Edit Profile"),
          ),
          const Divider(),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
              ),
              itemCount: 12,
              itemBuilder: (context, index) => Image.network(
                "https://picsum.photos/id/${index + 80}/300/300",
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 7. వీడియో రీల్ ఐటమ్ ---
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
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
        _controller.setLooping(true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          )
        : const Center(child: CircularProgressIndicator(color: Colors.white));
  }
}

// --- 8. చిన్న విడ్జెట్లు (Post & Story) ---
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
        ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(
              "https://picsum.photos/id/${widget.index + 20}/50/50",
            ),
          ),
          title: Text("User_${widget.index}"),
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
          CircleAvatar(
            radius: 35,
            backgroundColor: Colors.purple,
            child: CircleAvatar(
              radius: 32,
              backgroundImage: NetworkImage(
                "https://picsum.photos/id/${index + 50}/100/100",
              ),
            ),
          ),
          Text("User_$index", style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
