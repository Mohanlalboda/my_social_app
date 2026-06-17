// lib/screens/profile/add_highlight_sheet.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/firestore_methods.dart';

class AddHighlightSheet extends StatefulWidget {
  const AddHighlightSheet({super.key});

  @override
  State<AddHighlightSheet> createState() => _AddHighlightSheetState();
}

class _AddHighlightSheetState extends State<AddHighlightSheet> {
  final TextEditingController _titleController = TextEditingController();
  File? _coverImage;
  final List<File> _selectedMedias = [];
  bool _isLoading = false;

  Future<void> _pickCoverImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (pickedFile != null) {
      setState(() => _coverImage = File(pickedFile.path));
    }
  }

  Future<void> _pickMultipleMedia() async {
    final List<XFile> pickedFiles = await ImagePicker().pickMultipleMedia(
      imageQuality: 70,
    );
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedMedias.addAll(pickedFiles.map((e) => File(e.path)).toList());
      });
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _selectedMedias.removeAt(index);
    });
  }

  void _saveHighlight() async {
    if (_coverImage == null ||
        _selectedMedias.isEmpty ||
        _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Cover Image, Title, and at least 1 Photo are required! ⚠️",
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    String res = await FirestoreMethods().createHighlight(
      _titleController.text.trim(),
      _coverImage!,
      _selectedMedias,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res == "success") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Highlight created successfully! 🎉"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $res"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 🌟 THE FIX: కీబోర్డ్ ఓవర్‌ఫ్లో రాకుండా పర్ఫెక్ట్ స్క్రోలింగ్ స్ట్రక్చర్!
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(
          top: 20,
          left: 16,
          right: 16,
          bottom: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'Create New Highlight ✨',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const Divider(),
            const SizedBox(height: 10),

            GestureDetector(
              onTap: _pickCoverImage,
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blueAccent, width: 2),
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      image: _coverImage != null
                          ? DecorationImage(
                              image: FileImage(_coverImage!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _coverImage == null
                        ? const Icon(
                            Icons.add_a_photo,
                            color: Colors.grey,
                            size: 30,
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Add Cover",
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: "Highlight Title",
                hintText: "E.g., Goa Trip, Family, etc.",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Selected Media (${_selectedMedias.length})",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickMultipleMedia,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text("Add Media"),
                ),
              ],
            ),

            if (_selectedMedias.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedMedias.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 10, top: 10),
                          width: 70,
                          height: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(_selectedMedias[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _removeMedia(index),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.redAccent,
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            const SizedBox(height: 25),

            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _saveHighlight,
                    child: const Text(
                      'Save Highlight',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
