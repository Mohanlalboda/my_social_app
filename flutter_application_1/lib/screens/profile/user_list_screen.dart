import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/safe_elements.dart';
import 'other_user_profile_screen.dart';

class UserListScreen extends StatefulWidget {
  final String title;
  final List userIds;

  const UserListScreen({super.key, required this.title, required this.userIds});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  // 🌟 GHOST CLEANUP TRIGGER
  void _removeGhostUser(String ghostId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .update({
            'followers': FieldValue.arrayRemove([ghostId]),
            'following': FieldValue.arrayRemove([ghostId]),
          });
      debugPrint("🧹 Cleaned up Ghost ID: $ghostId");
    } catch (e) {
      debugPrint("Error cleaning ghost user: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDark ? Colors.black : Colors.white,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        elevation: 0.5,
      ),
      body: widget.userIds.isEmpty
          ? Center(
              child: Text(
                "No ${widget.title} yet.",
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: widget.userIds.length,
              itemBuilder: (context, index) {
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.userIds[index])
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isDark
                              ? Colors.grey[800]
                              : Colors.grey[300],
                          radius: 20,
                        ),
                        title: Container(
                          height: 10,
                          width: 100,
                          color: isDark ? Colors.grey[800] : Colors.grey[300],
                        ),
                      );
                    }

                    // 🌟 THE FIX: డాక్యుమెంట్ లేకపోతే (యూజర్ డిలీట్ అయితే) సైలెంట్ గా పీకేస్తాం
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      _removeGhostUser(widget.userIds[index]);
                      return const SizedBox();
                    }

                    var userData =
                        snapshot.data!.data() as Map<String, dynamic>? ?? {};
                    String name = userData['username'] ?? "User";
                    String profilePic = userData['profilePic'] ?? "";

                    return ListTile(
                      leading: SafeProfilePic(
                        base64String: profilePic,
                        radius: 20,
                        fallbackText: name.isNotEmpty
                            ? name[0].toUpperCase()
                            : "U",
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OtherUserProfileScreen(
                              userId: widget.userIds[index],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
