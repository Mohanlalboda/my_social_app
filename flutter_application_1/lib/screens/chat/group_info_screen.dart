// lib/screens/chat/group_info_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 🌟 THE FIX
import '../../services/firestore_methods.dart';

class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String groupPic;

  const GroupInfoScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.groupPic,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  bool _isUpdatingPic = false;

  void _leaveGroup(BuildContext context, String currentUid) async {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Leave Group? 🚪',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to exit from this group chat?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .doc(widget.groupId)
                  .update({
                    'users': FieldValue.arrayRemove([currentUid]),
                    'admins': FieldValue.arrayRemove([currentUid]),
                  });
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: const Text(
              'Leave',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _removeUser(String userId, String userName) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove User? 🚫',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to remove $userName from the group?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await FirestoreMethods().removeUserFromGroup(
                widget.groupId,
                userId,
              );
              if (mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("$userName removed successfully."),
                    backgroundColor: Colors.redAccent,
                  ),
                );
            },
            child: const Text(
              'Remove',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateGroupPic() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      setState(() => _isUpdatingPic = true);
      bool success = await FirestoreMethods().updateGroupProfilePic(
        widget.groupId,
        File(pickedFile.path),
      );
      setState(() => _isUpdatingPic = false);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Group profile picture updated! 🎉"),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        title: const Text(
          'Group Info',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chat_rooms')
            .doc(widget.groupId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || !snapshot.data!.exists)
            return const Center(child: Text("Group doesn't exist"));

          var groupData = snapshot.data!.data() as Map<String, dynamic>;
          List usersList = groupData['users'] ?? [];
          List adminsList = groupData['admins'] ?? [];
          bool amIAdmin = adminsList.contains(currentUid);
          String currentGroupPic = groupData['groupPic'] ?? widget.groupPic;
          String currentGroupName = groupData['groupName'] ?? widget.groupName;

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: amIAdmin ? _updateGroupPic : null,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[800],
                        backgroundImage: CachedNetworkImageProvider(
                          currentGroupPic,
                        ), // 🌟 THE FIX
                        child: _isUpdatingPic
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : null,
                      ),
                      if (amIAdmin && !_isUpdatingPic)
                        const Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.blueAccent,
                            child: Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  currentGroupName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Group • ${usersList.length} participants',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 25),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  color: isDark ? Colors.grey[900] : Colors.grey[200],
                  child: Text(
                    '${usersList.length} Participants',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: usersList.length,
                  itemBuilder: (context, index) {
                    String userUid = usersList[index];

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(userUid)
                          .get(),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData || !userSnap.data!.exists)
                          return const SizedBox.shrink();
                        var uData =
                            userSnap.data!.data() as Map<String, dynamic>;
                        bool isAdmin = adminsList.contains(userUid);
                        String userName = uData['username'] ?? 'User';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: CachedNetworkImageProvider(
                              uData['profilePic'] ??
                                  'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                            ), // 🌟 THE FIX
                          ),
                          title: Text(
                            userUid == currentUid ? 'You' : userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text(
                            uData['bio'] ?? 'Available',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isAdmin)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withAlpha(38),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Admin 👑',
                                    style: TextStyle(
                                      color: Colors.blueAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (amIAdmin && userUid != currentUid)
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () =>
                                      _removeUser(userUid, userName),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  child: Divider(height: 1, thickness: 0.5),
                ),

                ListTile(
                  onTap: () => _leaveGroup(context, currentUid),
                  leading: const Icon(
                    Icons.exit_to_app_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Leave Group',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}
