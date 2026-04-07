// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../widgets/safe_elements.dart';
import 'add_members_screen.dart';

class CommunityInfoScreen extends StatefulWidget {
  final String communityId;
  const CommunityInfoScreen({super.key, required this.communityId});

  @override
  State<CommunityInfoScreen> createState() => _CommunityInfoScreenState();
}

class _CommunityInfoScreenState extends State<CommunityInfoScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  bool _isUploadingPic = false;

  // 🌟 అడ్మిన్ గ్రూప్ పేరు ఎడిట్ చేయడానికి
  void _editGroupName(String currentName) {
    TextEditingController nameCtrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Group Name"),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(hintText: "Enter new name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('communities')
                    .doc(widget.communityId)
                    .update({'groupName': nameCtrl.text.trim()});
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 🌟 అడ్మిన్ గ్రూప్ డిస్క్రిప్షన్ ఎడిట్ చేయడానికి
  void _editGroupDesc(String currentDesc) {
    TextEditingController descCtrl = TextEditingController(text: currentDesc);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Description"),
        content: TextField(
          controller: descCtrl,
          maxLines: 3,
          decoration: const InputDecoration(hintText: "Enter description"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('communities')
                  .doc(widget.communityId)
                  .update({'description': descCtrl.text.trim()});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 🌟 అడ్మిన్ గ్రూప్ ఫోటో ఎడిట్ చేయడానికి
  void _updateGroupPic() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (image != null) {
      setState(() => _isUploadingPic = true);
      try {
        Reference ref = FirebaseStorage.instance
            .ref()
            .child('community_pics')
            .child(
              '${widget.communityId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
        await ref.putFile(File(image.path));
        String downloadUrl = await ref.getDownloadURL();
        await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .update({'groupPic': downloadUrl});
      } catch (e) {
        debugPrint("Update Pic Error: $e");
      } finally {
        if (mounted) setState(() => _isUploadingPic = false);
      }
    }
  }

  // 🌟 అడ్మిన్ వేరే మెంబర్ ని సెలెక్ట్ చేసినప్పుడు
  void _showMemberOptions(String memberId, String memberName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.all(15),
              child: Text(
                memberName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.admin_panel_settings,
                color: Colors.green,
              ),
              title: const Text("Make Group Admin (Transfer Rights)"),
              onTap: () async {
                Navigator.pop(ctx);
                await FirebaseFirestore.instance
                    .collection('communities')
                    .doc(widget.communityId)
                    .update({'adminId': memberId});
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.remove_circle_outline,
                color: Colors.red,
              ),
              title: Text(
                "Remove $memberName from group",
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await FirebaseFirestore.instance
                    .collection('communities')
                    .doc(widget.communityId)
                    .update({
                      'members': FieldValue.arrayRemove([memberId]),
                    });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[100],
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        title: const Text("Group Info"),
        elevation: 1,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text("Group deleted"));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          String name = data['groupName'] ?? "Community";
          String icon = data['groupPic'] ?? "";
          String desc = data['description'] ?? "";
          String adminId = data['adminId'] ?? "";
          List members = data['members'] ?? [];
          bool isAdmin = currentUid == adminId;

          return SingleChildScrollView(
            child: Column(
              children: [
                // 🌟 గ్రూప్ ఐకాన్ & పేరు సెక్షన్
                Container(
                  width: double.infinity,
                  color: isDark ? Colors.grey[900] : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: isAdmin ? _updateGroupPic : null,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            _isUploadingPic
                                ? const CircleAvatar(
                                    radius: 50,
                                    child: CircularProgressIndicator(),
                                  )
                                : SafeProfilePic(
                                    base64String: icon,
                                    radius: 50,
                                    fallbackText: name.isNotEmpty
                                        ? name[0]
                                        : 'C',
                                  ),
                            if (isAdmin)
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isAdmin)
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                size: 20,
                                color: Colors.blue,
                              ),
                              onPressed: () => _editGroupName(name),
                            ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              desc.isNotEmpty
                                  ? desc
                                  : (isAdmin ? "Add group description..." : ""),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (isAdmin)
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.blue,
                              ),
                              onPressed: () => _editGroupDesc(desc),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Group • ${members.length} members",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 🌟 మెంబర్స్ లిస్ట్ & యాడ్ మెంబర్స్ సెక్షన్
                Container(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(15),
                        child: Text(
                          "${members.length} participants",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      if (isAdmin)
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF833AB4),
                            child: Icon(Icons.person_add, color: Colors.white),
                          ),
                          title: const Text(
                            "Add Members",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddMembersScreen(
                                communityId: widget.communityId,
                                currentMembers: members,
                              ),
                            ),
                          ),
                        ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          String memberId = members[index];
                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(memberId)
                                .get(),
                            builder: (context, userSnap) {
                              if (!userSnap.hasData) return const SizedBox();
                              var userData =
                                  userSnap.data!.data()
                                      as Map<String, dynamic>? ??
                                  {};
                              String mName = userData['username'] ?? 'User';

                              return ListTile(
                                leading: SafeProfilePic(
                                  base64String: userData['profilePic'],
                                  radius: 20,
                                  fallbackText: mName[0],
                                ),
                                title: Text(
                                  mName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  userData['bio'] ?? '',
                                  maxLines: 1,
                                ),
                                trailing: memberId == adminId
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                        child: const Text(
                                          "Group Admin",
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 10,
                                          ),
                                        ),
                                      )
                                    : null,
                                onTap: (isAdmin && memberId != currentUid)
                                    ? () => _showMemberOptions(memberId, mName)
                                    : null,
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 🌟 ఎగ్జిట్ గ్రూప్ ఆప్షన్
                Container(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  child: ListTile(
                    leading: const Icon(Icons.exit_to_app, color: Colors.red),
                    title: const Text(
                      "Exit Group",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () async {
                      bool confirm =
                          await showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Exit Group?"),
                              content: const Text(
                                "Are you sure you want to leave this community?",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    "Exit",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ) ??
                          false;

                      if (confirm) {
                        if (isAdmin) {
                          if (members.length > 1) {
                            List remainingMembers = members
                                .where((id) => id != currentUid)
                                .toList();
                            String newAdminId =
                                remainingMembers[Random().nextInt(
                                  remainingMembers.length,
                                )];
                            await FirebaseFirestore.instance
                                .collection('communities')
                                .doc(widget.communityId)
                                .update({
                                  'members': FieldValue.arrayRemove([
                                    currentUid,
                                  ]),
                                  'adminId': newAdminId,
                                });
                          } else {
                            await FirebaseFirestore.instance
                                .collection('communities')
                                .doc(widget.communityId)
                                .delete();
                          }
                        } else {
                          await FirebaseFirestore.instance
                              .collection('communities')
                              .doc(widget.communityId)
                              .update({
                                'members': FieldValue.arrayRemove([currentUid]),
                              });
                        }
                        if (context.mounted) {
                          Navigator.pop(context);
                          Navigator.pop(context);
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }
}
