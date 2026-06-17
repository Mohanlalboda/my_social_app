// lib/widgets/create_group_sheet.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_methods.dart';

class CreateGroupSheet extends StatefulWidget {
  const CreateGroupSheet({super.key});

  @override
  State<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<CreateGroupSheet> {
  final TextEditingController _groupNameController = TextEditingController();
  final List<String> _selectedUserIds = [];
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  bool _isLoading = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  void _submitGroup() async {
    if (_groupNameController.text.trim().isEmpty || _selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please enter Group Name and select at least 1 friend! ⚠️",
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
   // 🌟 THE FIX: మీ UID ని కూడా గ్రూప్ మెంబర్స్ లిస్ట్ లో కలుపుతున్నాం 
List<String> finalMembers = List.from(_selectedUserIds);
if (!finalMembers.contains(currentUid)) {
  finalMembers.add(currentUid); 
}

bool success = await FirestoreMethods().createGroupChat(
  groupName: _groupNameController.text.trim(),
  groupPic: '', // 🌟 THE FIX: ఇక్కడ groupPic ని ఖాళీగా పంపుతున్నాం (తర్వాత గ్రూప్ లో మార్చుకోవచ్చు)
  memberIds: finalMembers,
);
    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Group Created Successfully! 🎉"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'Create New Group 👥',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _groupNameController,
            decoration: InputDecoration(
              hintText: 'Enter Group Name...',
              filled: true,
              fillColor: isDark ? Colors.grey[850] : Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 15),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Select Friends:',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var users = snapshot.data!.docs
                    .where((doc) => doc.id != currentUid)
                    .toList();

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    var userData = users[index].data() as Map<String, dynamic>;
                    String uid = users[index].id;
                    bool isSelected = _selectedUserIds.contains(uid);

                    return CheckboxListTile(
                      title: Text(
                        userData['username'] ?? 'User',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      secondary: CircleAvatar(
                        backgroundImage: CachedNetworkImageProvider(
                          userData['profilePic'] ??
                              'https://cdn.pixabay.com/photo/...',
                        ),
                      ),
                      value: isSelected,
                      activeColor: Colors.blueAccent,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedUserIds.add(uid);
                          } else {
                            _selectedUserIds.remove(uid);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitGroup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Create Group 🚀',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
