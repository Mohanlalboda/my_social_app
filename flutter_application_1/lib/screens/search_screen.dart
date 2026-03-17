import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/safe_elements.dart';
import 'other_user_profile_screen.dart';
import 'scrolling_posts_screen.dart';
import 'single_reel_screen.dart'; // నిన్న మనం చేసిన సింగిల్ రీల్ పేజీ

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController searchController = TextEditingController();
  bool isShowUsers = false;

  // 🌟 డేటాబేస్ నుండి పోస్ట్‌లు మరియు రీల్స్ రెండింటినీ లాగి కలిపే ఫంక్షన్ (Explore కోసం)
  Future<List<Map<String, dynamic>>> getExploreContent() async {
    List<Map<String, dynamic>> allContent = [];

    try {
      // 1. పోస్ట్స్ లాగుతున్నాం
      var postsSnap = await FirebaseFirestore.instance
          .collection('posts')
          .limit(20)
          .get();
      for (var doc in postsSnap.docs) {
        var data = doc.data();
        data['item_type'] = 'post'; // ఇది పోస్ట్ అని గుర్తుపెట్టుకోవడానికి
        data['id'] = doc.id;
        allContent.add(data);
      }

      // 2. రీల్స్ లాగుతున్నాం
      var reelsSnap = await FirebaseFirestore.instance
          .collection('reels')
          .limit(20)
          .get();
      for (var doc in reelsSnap.docs) {
        var data = doc.data();
        data['item_type'] = 'reel'; // ఇది రీల్ అని గుర్తుపెట్టుకోవడానికి
        data['id'] = doc.id;
        allContent.add(data);
      }

      // 3. వాటిని షఫుల్ (మిక్స్) చేస్తున్నాం (ఇన్‌స్టాగ్రామ్ ఫీల్ కోసం)
      allContent.shuffle();
    } catch (e) {
      debugPrint("Explore Fetch Error: $e");
    }

    return allContent;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: TextFormField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Search for a user...',
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            suffixIcon: isShowUsers
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        searchController.clear();
                        isShowUsers =
                            false; // క్లియర్ చేయగానే మళ్లీ ఎక్స్‌ప్లోర్ గ్రిడ్ వస్తుంది
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.grey.shade200,
            contentPadding: const EdgeInsets.all(8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          onFieldSubmitted: (String _) {
            setState(() {
              isShowUsers = searchController.text.trim().isNotEmpty;
            });
          },
          onChanged: (String text) {
            if (text.isEmpty) {
              setState(() {
                isShowUsers = false;
              });
            }
          },
        ),
      ),

      // 🌟 ఎవరైనా పేరు సెర్చ్ చేస్తే ఆ యూజర్ లిస్ట్ వస్తుంది, లేకపోతే రీల్స్+పోస్ట్స్ గ్రిడ్ వస్తుంది!
      body: isShowUsers ? _buildUserSearchStream() : _buildExploreGrid(),
    );
  }

  // 👤 1. యూజర్లని సెర్చ్ చేసినప్పుడు చూపించే లిస్ట్
  Widget _buildUserSearchStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where(
            'username',
            isGreaterThanOrEqualTo: searchController.text.trim(),
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var users = snapshot.data!.docs;

        if (users.isEmpty) {
          return const Center(
            child: Text(
              "No users found.",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            var userData = users[index].data() as Map<String, dynamic>;
            String username = userData['username'] ?? 'User';

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                username,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                userData['bio'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                // యూజర్ పేరు మీద క్లిక్ చేస్తే ప్రొఫైల్ ఓపెన్ అవుతుంది
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        OtherUserProfileScreen(uid: users[index].id),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // 📸🎬 2. సెర్చ్ చేయనప్పుడు ఇన్‌స్టాగ్రామ్ లాగా చూపించే ఎక్స్‌ప్లోర్ గ్రిడ్
  Widget _buildExploreGrid() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: getExploreContent(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              "No posts or reels yet. Follow some people! 🌟",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        List<Map<String, dynamic>> exploreData = snapshot.data!;

        // కేవలం పోస్ట్‌ల ఐడీలను మాత్రమే ఫిల్టర్ చేస్తున్నాం (స్క్రోలింగ్ స్క్రీన్ కి పంపడానికి)
        List<String> onlyPostIds = exploreData
            .where((item) => item['item_type'] == 'post')
            .map((item) => item['id'] as String)
            .toList();

        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 1, // స్క్వేర్ షేప్ లో వస్తాయి
          ),
          itemCount: exploreData.length,
          itemBuilder: (context, index) {
            var item = exploreData[index];
            bool isReel = item['item_type'] == 'reel';

            return GestureDetector(
              onTap: () {
                if (isReel) {
                  // 🎬 రీల్ అయితే సింగిల్ రీల్ వ్యూ ఓపెన్ అవుతుంది
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          SingleReelScreen(reelId: item['id']),
                    ),
                  );
                } else {
                  // 📸 పోస్ట్ అయితే స్క్రోలింగ్ పోస్ట్స్ వ్యూ ఓపెన్ అవుతుంది
                  int actualIndex = onlyPostIds.indexOf(item['id']);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ScrollingPostsScreen(
                        postIds: onlyPostIds,
                        initialIndex: actualIndex != -1 ? actualIndex : 0,
                      ),
                    ),
                  );
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // బ్యాక్‌గ్రౌండ్ ఇమేజ్ (పోస్ట్ కి అయితే ఫోటో, రీల్ అయితే ప్రస్తుతానికి బ్లాక్ బాక్స్)
                  isReel
                      ? Container(color: Colors.black87)
                      : SafeImage(base64String: item['postData']),

                  // రీల్ అయితే పైన కుడివైపు మూలలో రీల్స్ ఐకాన్
                  if (isReel)
                    const Positioned(
                      top: 5,
                      right: 5,
                      child: Icon(
                        Icons.video_library,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),

                  // రీల్ అయితే మధ్యలో చిన్న ప్లే ఐకాన్
                  if (isReel)
                    const Center(
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white54,
                        size: 40,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
