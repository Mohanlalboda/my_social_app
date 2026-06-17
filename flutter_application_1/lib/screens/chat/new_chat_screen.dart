// lib/screens/chat/new_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 🌟 THE FIX
import '../../widgets/create_group_sheet.dart';
import 'chat_room_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          'New Chat 📝',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: textColor,
          ),
        ),
      ),
      body: Column(
        children: [
          // 1️⃣ 🔍 పవర్‌ఫుల్ సెర్చ్ బార్ బాస్
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: textColor),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search users... 🔍',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: isDark ? Colors.grey[900] : Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          // 2️⃣ 👥 CREATE GROUP OPTION ROW (దీనిపై నొక్కితే గ్రూప్ షీట్ ఓపెన్ అవుతుంది బాస్)
          ListTile(
            onTap: () {
              // ఇక్కడి నుండి నేరుగా మనం బిల్డ్ చేసిన గ్రూప్ క్రియేషన్ బాటమ్ షీట్ ఓపెన్ అవుతుంది
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                builder: (context) => const CreateGroupSheet(),
              );
            },
            leading: const CircleAvatar(
              backgroundColor: Colors.blueAccent,
              child: Icon(Icons.group_add_rounded, color: Colors.white),
            ),
            title: Text(
              'Create a New Group 👥',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textColor,
                fontSize: 15,
              ),
            ),
            subtitle: const Text(
              'Chat with multiple friends together',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey,
            ),
          ),
          const Divider(height: 20, thickness: 0.5),

          // 3️⃣ 👤 CONTACTS / USERS LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No users found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                // మన ఐడీ కాకుండా మిగిలిన యూజర్లను ఫిల్టర్ చేసి సెర్చ్ క్వెరీ మ్యాచ్ చేస్తాం బాస్
                var filteredUsers = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String uid = doc.id;
                  String username = (data['username'] ?? '')
                      .toString()
                      .toLowerCase();

                  bool isNotMe = uid != currentUid;
                  bool matchesSearch = username.contains(_searchQuery);

                  return isNotMe && matchesSearch;
                }).toList();

                if (filteredUsers.isEmpty) {
                  return const Center(
                    child: Text(
                      'No matches found 🏜️',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    var userData =
                        filteredUsers[index].data() as Map<String, dynamic>;
                    String uid = filteredUsers[index].id;
                    String username = userData['username'] ?? 'User';
                    String profilePic = userData['profilePic'] ?? '';

                    return ListTile(
                      onTap: () {
                        // క్లిక్ చేయగానే ఈ స్క్రీన్‌ని పాప్ చేసి నేరుగా పర్సనల్ చాట్ రూమ్‌కి తీసుకెళ్తాం 🚀
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatRoomScreen(
                              receiverUid: uid,
                              receiverUsername: username,
                            ),
                          ),
                        );
                      },
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: profilePic.isNotEmpty
                            ? CachedNetworkImageProvider(
                                profilePic,
                              ) // 🌟 Image Cache Appiled
                            : const CachedNetworkImageProvider(
                                'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                              ),
                      ),
                      title: Text(
                        username,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      subtitle: Text(
                        userData['bio'] ?? 'Hey there!',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
