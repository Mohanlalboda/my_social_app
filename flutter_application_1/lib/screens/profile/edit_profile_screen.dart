// lib/screens/profile/edit_profile_screen.dart

import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _villageController;

  File? _imageFile;
  bool _isLoading = false;
  final String _currentUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.userData['username'] ?? '',
    );
    _bioController = TextEditingController(text: widget.userData['bio'] ?? '');
    _villageController = TextEditingController(
      text: widget.userData['village'] ?? '',
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _villageController.dispose();
    super.dispose();
  }

  Future<void> _selectImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _updateProfileData() async {
    String username = _usernameController.text.trim();
    String bio = _bioController.text.trim();
    String village = _villageController.text.trim();

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Username cannot be empty! ❌"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String profilePicUrl = widget.userData['profilePic'] ?? '';

      if (_imageFile != null) {
        Reference ref = FirebaseStorage.instance
            .ref()
            .child('profilePics')
            .child(_currentUid);
        UploadTask uploadTask = ref.putFile(_imageFile!);
        TaskSnapshot snap = await uploadTask;
        profilePicUrl = await snap.ref.getDownloadURL();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .update({
            'username': username,
            'bio': bio,
            'village':
                village, // 🏡 గ్రామ ఫీడ్ ఆటోమేటిక్‌గా సింక్ అవుతుంది బాస్!
            'profilePic': profilePicUrl,
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profile updated successfully! 🎉"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error updating profile: $e ❌"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          'Edit Profile 📝',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: textColor,
          ),
        ),
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(
                    Icons.check_rounded,
                    color: Colors.blueAccent,
                    size: 28,
                  ),
                  onPressed: _updateProfileData,
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _selectImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _imageFile != null
                        ? FileImage(_imageFile!) as ImageProvider
                        : CachedNetworkImageProvider(
                            widget.userData['profilePic']
                                        ?.toString()
                                        .isNotEmpty ==
                                    true
                                ? widget.userData['profilePic']
                                : 'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                          ),
                  ),
                  const Positioned(
                    bottom: 0,
                    right: 4,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.blueAccent,
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Change Profile Photo',
              style: TextStyle(
                color: Colors.blueAccent,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            _buildEditField(
              controller: _usernameController,
              label: 'Username',
              hint: 'Enter your nickname...',
              icon: Icons.person_outline_rounded,
              textColor: textColor,
              isDark: isDark,
            ),
            const SizedBox(height: 20),
            _buildEditField(
              controller: _villageController,
              label: 'Village / Tanda 🏡',
              hint: 'e.g. Kalyan Thanda, Balaji Nagar...',
              icon: Icons.home_work_outlined,
              textColor: textColor,
              isDark: isDark,
            ),
            const SizedBox(height: 20),
            _buildEditField(
              controller: _bioController,
              label: 'Bio',
              hint: 'Tell the community about yourself...',
              icon: Icons.edit_note_rounded,
              textColor: textColor,
              isDark: isDark,
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color textColor,
    required bool isDark,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: textColor, fontSize: 14.5),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 13.5),
            prefixIcon: Icon(icon, color: Colors.grey, size: 22),
            filled: true,
            fillColor: isDark ? Colors.grey[950] : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ), // 🌟 నేటివ్ ఫిక్స్ బాస్!
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blueAccent, width: 1),
            ),
          ),
        ),
      ],
    );
  }
}
