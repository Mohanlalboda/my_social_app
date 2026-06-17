// lib/widgets/share_media_sheet.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_methods.dart';

class ShareMediaSheet extends StatefulWidget {
  final String mediaId;
  final String mediaUrl;
  final bool isReel;

  const ShareMediaSheet({
    super.key,
    required this.mediaId,
    required this.mediaUrl,
    this.isReel = false,
  });

  @override
  State<ShareMediaSheet> createState() => _ShareMediaSheetState();
}

class _ShareMediaSheetState extends State<ShareMediaSheet> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  final Map<String, bool> _sendingState =
      {}; // ప్రతి యూజర్ సెండింగ్ స్టేట్ ట్రాక్ చేయడానికి

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Send to Friends ✈️',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                // మన ఐడీ కాకుండా మిగతా యూజర్లను ఫిల్టర్ చేస్తాం బాస్
                var friends = snapshot.data!.docs
                    .where((doc) => doc.id != currentUid)
                    .toList();

                if (friends.isEmpty) {
                  return const Center(
                    child: Text('No friends found to share.'),
                  );
                }

                return ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    var userDoc = friends[index];
                    var userData = userDoc.data() as Map<String, dynamic>;
                    String uid = userDoc.id;
                    String username = userData['username'] ?? 'User';
                    String profilePic = userData['profilePic'] ?? '';

                    bool isSent = _sendingState[uid] ?? false;

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundImage: CachedNetworkImageProvider(profilePic.isNotEmpty ? profilePic : 'https://cdn.pixabay.com/photo/...'),
                      ),
                      title: Text(
                        username,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: ElevatedButton(
                        onPressed: isSent
                            ? null
                            : () async {
                                setState(() => _sendingState[uid] = true);

                                // ఫైర్‌స్టోర్ సర్వీస్ ద్వారా చాట్‌లోకి పంపడం 🚀
                                bool success = await FirestoreMethods()
                                    .shareMediaToChat(
                                      receiverId: uid,
                                      mediaId: widget.mediaId,
                                      mediaUrl: widget.mediaUrl,
                                      senderUsername: username,
                                      isReel: widget.isReel,
                                    );

                                if (success && mounted) {
                                  setState(
                                    () => _sendingState[uid] = true,
                                  ); // Sent స్టేట్ లోనే ఉంచుతాం
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSent
                              ? Colors.grey
                              : Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: Text(
                          isSent ? 'Sent ✓' : 'Send',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
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
