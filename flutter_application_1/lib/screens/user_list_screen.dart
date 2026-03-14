import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/safe_elements.dart';
import 'other_user_profile_screen.dart';

class UserListScreen extends StatelessWidget {
  final String title;
  final List userIds;

  const UserListScreen({super.key, required this.title, required this.userIds});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: userIds.isEmpty
          ? Center(child: Text("No $title yet."))
          : ListView.builder(
              itemCount: userIds.length,
              itemBuilder: (context, index) {
                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(userIds[index])
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    
                    var userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                    String name = userData['username'] ?? "User";
                    String profilePic = userData['profilePic'] ?? "";

                    return ListTile(
                      leading: SafeProfilePic(
                        base64String: profilePic,
                        radius: 20,
                        fallbackText: name.isNotEmpty ? name[0] : "U",
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OtherUserProfileScreen(uid: userIds[index]),
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