import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MySocialApp());
}

class MySocialApp extends StatefulWidget {
  const MySocialApp({super.key});
  @override
  State<MySocialApp> createState() => _MySocialAppState();
}

class _MySocialAppState extends State<MySocialApp> {
  ThemeMode _themeMode = ThemeMode.light;
  void _toggleTheme() => setState(
    () => _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.light, primaryColor: Colors.blue),
      darkTheme: ThemeData(brightness: Brightness.dark),
      themeMode: _themeMode,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return MainNavigation(toggleTheme: _toggleTheme);
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

// --- 2. మెయిన్ నావిగేషన్ ---
class MainNavigation extends StatefulWidget {
  final VoidCallback toggleTheme;
  const MainNavigation({super.key, required this.toggleTheme});
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
      appBar: AppBar(
        title: const Text(
          "Instagram",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: widget.toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.blue,
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

// --- 3. హోమ్ స్క్రీన్ ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isUploading = false;

  Future<void> _uploadPost() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 25,
      maxWidth: 800, // వెడల్పును 800 పిక్సెల్స్ కి పరిమితం చేయండి
      maxHeight: 800,
    );

    if (image != null) {
      setState(() => _isUploading = true);
      try {
        File imageFile = File(image.path);
        String base64Image = base64Encode(await imageFile.readAsBytes());
        String uid = FirebaseAuth.instance.currentUser!.uid;
        String postId = DateTime.now().millisecondsSinceEpoch.toString();

        await FirebaseDatabase.instance.ref("posts").child(postId).set({
          "postId": postId,
          "ownerId": uid,
          "postData": base64Image,
          "username": FirebaseAuth.instance.currentUser!.email!.split('@')[0],
          "timestamp": ServerValue.timestamp,
        });

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Post Shared! 🌎")));
        }
      } catch (e) {
        debugPrint("Error: $e");
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadPost,
        child: const Icon(Icons.add_a_photo),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 8,
              itemBuilder: (context, index) => StoryWidget(index: index),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isUploading
                ? const Center(child: CircularProgressIndicator())
                : FirebaseAnimatedList(
                    query: FirebaseDatabase.instance.ref("posts"),
                    reverse: true,
                    itemBuilder: (context, snapshot, animation, index) {
                      Map post = snapshot.value as Map;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              child: Text(post['username'][0].toUpperCase()),
                            ),
                            title: Text(post['username'] ?? "User"),
                          ),
                          Image.memory(
                            base64Decode(post['postData']),
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// --- 4. లాగిన్ స్క్రీన్ ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _login() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Instagram Clone",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _login,
                child: const Text("Log In"),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SignUpScreen()),
              ),
              child: const Text("Don't have an account? Sign Up"),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 5. సైన్ అప్ స్క్రీన్ ---
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  Future<void> _signUp() async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
      await FirebaseDatabase.instance
          .ref("users/${userCredential.user!.uid}")
          .set({
            "username": _usernameController.text.trim(),
            "email": _emailController.text.trim(),
            "uid": userCredential.user!.uid,
            "bio": "Law Student | Building my app ⚖️",
          });
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Account")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: "Username",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _signUp,
                child: const Text("Sign Up"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 6. సెర్చ్ స్క్రీన్ ---
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
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
    );
  }
}

// --- 7. రీల్స్ స్క్రీన్ ---
class ReelsScreen extends StatelessWidget {
  const ReelsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return PageView.builder(
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
            Positioned(
              right: 15,
              bottom: 100,
              child: Column(
                children: [
                  const Icon(Icons.favorite, color: Colors.white, size: 35),
                  const Text("1.2k", style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// --- 8. ప్రొఫైల్ స్క్రీన్ ---
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder(
      stream: FirebaseDatabase.instance.ref("users/$uid").onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        String name =
            snapshot.data?.snapshot.child("username").value.toString() ??
            "User";
        String bio =
            snapshot.data?.snapshot.child("bio").value.toString() ?? "";
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(radius: 40, child: Text(name[0].toUpperCase())),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(bio),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            const Text("My Activity"),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                ),
                itemCount: 9,
                itemBuilder: (context, index) => Image.network(
                  "https://picsum.photos/id/${index + 10}/200/200",
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// --- 9. వీడియో రీల్ ఐటమ్ ---
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
        if (mounted) setState(() {});
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
        : const Center(child: CircularProgressIndicator());
  }
}

// --- 10. స్టోరీ విడ్జెట్ ---
class StoryWidget extends StatelessWidget {
  final int index;
  const StoryWidget({super.key, required this.index});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: NetworkImage(
              "https://picsum.photos/id/${index + 100}/100/100",
            ),
          ),
          Text("User_$index"),
        ],
      ),
    );
  }
}
