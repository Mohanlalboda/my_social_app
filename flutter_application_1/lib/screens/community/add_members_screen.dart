// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/safe_elements.dart';

class AddMembersScreen extends StatefulWidget {
  final String communityId;
  final List currentMembers;

  const AddMembersScreen({
    super.key,
    required this.communityId,
    required this.currentMembers,
  });

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  List<String> selectedUsers = [];
  bool isAdding = false;

  void _addSelectedMembers() async {
    if (selectedUsers.isEmpty) return;
    setState(() => isAdding = true);

    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .update({'members': FieldValue.arrayUnion(selectedUsers)});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Members Added Successfully! ✅")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Add Members Error: $e");
    } finally {
      if (mounted) setState(() => isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: const Text("Add Members"),
        backgroundColor: isDark ? Colors.black : Colors.white,
        actions: [
          if (selectedUsers.isNotEmpty)
            IconButton(
              icon: isAdding
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.blue,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check, color: Colors.blue, size: 30),
              onPressed: isAdding ? null : _addSelectedMembers,
            ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        // మీ following లిస్ట్ తెచ్చుకుంటున్నాం
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          List following =
              (snapshot.data!.data() as Map<String, dynamic>)['following'] ??
              [];

          // గ్రూప్ లో ఆల్రెడీ ఉన్నవాళ్ళని లిస్ట్ నుండి తీసేస్తున్నాం
          List availableUsers = following
              .where((id) => !widget.currentMembers.contains(id))
              .toList();

          if (availableUsers.isEmpty) {
            return const Center(
              child: Text(
                "No new users to add.",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: availableUsers.length,
            itemBuilder: (context, index) {
              String userId = availableUsers[index];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData || !userSnap.data!.exists) {
                    return const SizedBox();
                  }
                  var userData = userSnap.data!.data() as Map<String, dynamic>;

                  bool isSelected = selectedUsers.contains(userId);

                  return CheckboxListTile(
                    activeColor: const Color(0xFF833AB4),
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          selectedUsers.add(userId);
                        } else {
                          selectedUsers.remove(userId);
                        }
                      });
                    },
                    secondary: SafeProfilePic(
                      base64String: userData['profilePic'],
                      radius: 20,
                      fallbackText: userData['username'][0].toUpperCase(),
                    ),
                    title: Text(
                      userData['username'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(userData['bio'] ?? '', maxLines: 1),
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
