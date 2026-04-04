import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/safe_elements.dart';
import 'other_user_profile_screen.dart';

class UserListScreen extends StatelessWidget {
  final String title;
  final List userIds;

  const UserListScreen({super.key, required this.title, required this.userIds});

  @override
  Widget build(BuildContext context) {
    // 🌟 డార్క్ మోడ్ సపోర్ట్
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDark ? Colors.black : Colors.white,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        elevation: 0.5,
      ),
      body: userIds.isEmpty
          ? Center(
              child: Text(
                "No $title yet.",
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: userIds.length,
              itemBuilder: (context, index) {
                // 🌟 ఫాస్ట్ గా లోడ్ అవ్వడానికి Stream బదులు Future వాడాం (లిస్ట్ ఊరికే మారదు కాబట్టి డేటా సేవ్ అవుతుంది)
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(userIds[index])
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      // 🌟 డేటా వచ్చేలోపు చిన్న లోడింగ్ షిమ్మర్ లాంటిది
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
                    if (!snapshot.hasData || !snapshot.data!.exists) {
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
                            builder: (context) =>
                                OtherUserProfileScreen(userId: userIds[index]),
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
