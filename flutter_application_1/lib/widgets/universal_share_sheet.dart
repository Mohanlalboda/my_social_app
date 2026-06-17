// lib/widgets/universal_share_sheet.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../services/firestore_methods.dart';

// 🌟 ఏ ఫ్లేవర్ (Dev / Prod) లో ఉన్నామో తెలుసుకోవడానికి
const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');

class UniversalShareSheet extends StatefulWidget {
  final String postId;
  final String postType; // 'post', 'reel', 'audio'
  final String mediaUrl;
  final String title;

  const UniversalShareSheet({
    super.key,
    required this.postId,
    required this.postType,
    required this.mediaUrl,
    required this.title,
  });

  @override
  State<UniversalShareSheet> createState() => _UniversalShareSheetState();
}

class _UniversalShareSheetState extends State<UniversalShareSheet> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  String searchQuery = "";
  List<String> selectedUsers = [];

  // 🌟 THE FIX: Dev అయితే లింక్ లో 'env=dev' అని యాడ్ అవుతుంది
  Future<void> _shareExternally() async {
    String myDeepLink =
        "https://my-social-app-d3394.web.app/share?id=${widget.postId}&type=${widget.postType}&env=$flavor";

    String shareText =
        "Check out this amazing ${widget.postType} on MyBanjara! 🚀\n\n${widget.title}\n\nWatch here: $myDeepLink";

    if (mounted) Navigator.pop(context); // షీట్ క్లోజ్

    // వాట్సాప్/ఇన్స్టా కి షేర్ విండో ఓపెన్ అవుతుంది
    // ignore: deprecated_member_use
    await Share.share(shareText, subject: "MyBanjara Content");
  }

  void _sendInternally() async {
    if (selectedUsers.isEmpty) return;

    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Sending... 🚀")));

    for (String uid in selectedUsers) {
      await FirestoreMethods().sendMessage(
        uid,
        "Shared a ${widget.postType}: ${widget.mediaUrl}",
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sent successfully! ✅"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 15),

          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search friends...",
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[800],
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
          ),
          const SizedBox(height: 15),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var users = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  bool isNotMe = doc.id != currentUid;
                  bool matchesSearch = (data['username'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(searchQuery);
                  return isNotMe && matchesSearch;
                }).toList();

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    var user = users[index].data() as Map<String, dynamic>;
                    String uid = users[index].id;
                    bool isSelected = selectedUsers.contains(uid);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          isSelected
                              ? selectedUsers.remove(uid)
                              : selectedUsers.add(uid);
                        });
                      },
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundImage: CachedNetworkImageProvider(user['profilePic'] ?? 'https://cdn.pixabay.com/photo/...'),
                              ),
                              if (isSelected)
                                const Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Colors.blueAccent,
                                    child: Icon(
                                      Icons.check,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            user['username'] ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(color: Colors.white24),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildExternalShareBtn(
                  Icons.copy_rounded,
                  "Copy Link",
                  _shareExternally,
                ),
                _buildExternalShareBtn(
                  Icons.share_rounded,
                  "Share via...",
                  _shareExternally,
                ),
              ],
            ),
          ),

          if (selectedUsers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20, top: 10),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: _sendInternally,
                child: Text(
                  "Send to ${selectedUsers.length} friends",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExternalShareBtn(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.grey[800],
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
