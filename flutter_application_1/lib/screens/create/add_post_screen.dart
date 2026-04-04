// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../../widgets/safe_elements.dart';
import 'package:geolocator/geolocator.dart'; // 🌟 GPS కోసం

// 🌟 బ్యాక్‌గ్రౌండ్ అప్‌లోడ్స్ మేనేజర్
// 🌟 బ్యాక్‌గ్రౌండ్ అప్‌లోడ్స్ మేనేజర్ (With GPS Location)
class UploadManager {
  static final UploadManager _instance = UploadManager._internal();
  factory UploadManager() => _instance;
  UploadManager._internal();

  final ValueNotifier<bool> isUploading = ValueNotifier(false);
  final ValueNotifier<double> uploadProgress = ValueNotifier(0.0);
  final ValueNotifier<String> uploadStatus = ValueNotifier("");

  // 📍 GPS లొకేషన్ తెచ్చుకునే ఫంక్షన్
  Future<Position?> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null; // GPS ఆన్ లేదు

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null; // పర్మిషన్ లేదు
    }

    if (permission == LocationPermission.deniedForever) return null;

    try {
      // 🌟 FIX: Deprecated 'desiredAccuracy' వార్నింగ్ క్లియర్ చేశాం
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      debugPrint("Location Error: $e");
      return null;
    }
  }

  // 📸 ఫోటో పోస్ట్ అప్‌లోడ్
  Future<void> backgroundUploadPost(
    List<File> images,
    String caption,
    bool isPublic,
    List<String> taggedFriends,
  ) async {
    isUploading.value = true;
    uploadProgress.value = 0.0;
    uploadStatus.value = "Getting Location...";

    try {
      // 🌟 1. ముందే లొకేషన్ తెచ్చుకోవడం
      Position? currentPosition = await _getUserLocation();

      String uid = FirebaseAuth.instance.currentUser!.uid;
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      String username = userDoc.data()?['username'] ?? 'User';
      String profilePic = userDoc.data()?['profilePic'] ?? '';

      List<String> imageUrls = [];
      final tempDir = await getTemporaryDirectory();

      for (int i = 0; i < images.length; i++) {
        uploadStatus.value = "Compressing Image ${i + 1}...";
        String imageId = const Uuid().v4();
        final outPath = "${tempDir.path}/post_$imageId.jpg";
        var compressedImage = await FlutterImageCompress.compressAndGetFile(
          images[i].path,
          outPath,
          quality: 70,
          minWidth: 1080,
          minHeight: 1080,
        );

        File fileToUpload = compressedImage != null
            ? File(compressedImage.path)
            : images[i];
        Reference ref = FirebaseStorage.instance
            .ref()
            .child('posts')
            .child(uid)
            .child('$imageId.jpg');
        UploadTask uploadTask = ref.putFile(fileToUpload);

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          uploadProgress.value =
              snapshot.bytesTransferred / snapshot.totalBytes;
          uploadStatus.value =
              "Uploading Image ${i + 1} of ${images.length}...";
        });

        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();
        imageUrls.add(downloadUrl);
      }

      uploadStatus.value = "Finishing up...";
      String postId = const Uuid().v4();

      // 🌟 2. లొకేషన్ తో సహా డేటాబేస్‌లో సేవ్ చేయడం
      Map<String, dynamic> postData = {
        'postId': postId,
        'ownerId': uid,
        'username': username,
        'profilePic': profilePic,
        'postData': imageUrls,
        'type': 'image',
        'caption': caption,
        'likes': [],
        'savedBy': [],
        'isPublic': isPublic,
        'taggedUsers': taggedFriends,
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (currentPosition != null) {
        postData['latitude'] = currentPosition.latitude;
        postData['longitude'] = currentPosition.longitude;
      }

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .set(postData);
    } catch (e) {
      debugPrint("Background Post Error: $e");
    } finally {
      isUploading.value = false;
    }
  }

  // 🎥 వీడియో (Reel) అప్‌లోడ్
  Future<void> backgroundUploadReel(
    File video,
    String caption,
    bool isPublic,
    List<String> taggedFriends,
  ) async {
    isUploading.value = true;
    uploadProgress.value = 0.0;
    uploadStatus.value = "Getting Location...";

    try {
      // 🌟 1. ముందే లొకేషన్ తెచ్చుకోవడం
      Position? currentPosition = await _getUserLocation();

      String uid = FirebaseAuth.instance.currentUser!.uid;
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      String username = userDoc.data()?['username'] ?? 'User';
      String profilePic = userDoc.data()?['profilePic'] ?? '';
      String postId = const Uuid().v4();

      uploadStatus.value = "Compressing Video...";
      MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        video.path,
        quality: VideoQuality.MediumQuality,
        includeAudio: true,
      );

      File fileToUpload = (mediaInfo != null && mediaInfo.file != null)
          ? mediaInfo.file!
          : video;

      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('reels')
          .child('$postId.mp4');
      UploadTask uploadTask = storageRef.putFile(fileToUpload);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        uploadProgress.value = progress;
        uploadStatus.value =
            "Uploading Reel... ${(progress * 100).toStringAsFixed(1)}%";
      });

      TaskSnapshot snapshot = await uploadTask;
      String videoUrl = await snapshot.ref.getDownloadURL();

      // 🌟 2. లొకేషన్ తో సహా డేటాబేస్‌లో సేవ్ చేయడం
      Map<String, dynamic> reelData = {
        'postId': postId, // రీల్స్ ని కూడా యాప్ అంతా వాడుకోవడానికి
        'ownerId': uid,
        'username': username,
        'profilePic': profilePic,
        'postData': [videoUrl], // కన్సిస్టెన్సీ కోసం
        'mediaUrl': videoUrl,
        'type': 'video',
        'description': caption, // టిక్‌టాక్ లాంటి పేజీ కోసం
        'caption': caption, // హోమ్ ఫీడ్ కోసం
        'likes': [],
        'savedBy': [],
        'isPublic': isPublic,
        'taggedUsers': taggedFriends,
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (currentPosition != null) {
        reelData['latitude'] = currentPosition.latitude;
        reelData['longitude'] = currentPosition.longitude;
      }

      // రీల్ ని 'reels' కలెక్షన్ లో సేవ్ చేయడం
      await FirebaseFirestore.instance
          .collection('reels')
          .doc(postId)
          .set(reelData);

      // కావాలంటే 'posts' లో కూడా సేవ్ చేయొచ్చు (హోమ్ ఫీడ్ లో కనిపించడానికి)
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .set(reelData);
    } catch (e) {
      debugPrint("Background Reel Error: $e");
    } finally {
      VideoCompress.deleteAllCache();
      isUploading.value = false;
    }
  }
}

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});
  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  final List<Map<String, String>> _taggedUsers = [];

  List<File> _selectedImages = [];
  final TextEditingController _postCaptionController = TextEditingController();
  bool _isPostPublic = true;

  File? _selectedVideo;
  final TextEditingController _reelCaptionController = TextEditingController();
  bool _isReelPublic = true;

  void _selectFriends() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(currentUid)
                .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator()),
                );
              List following =
                  (snapshot.data!.data()
                      as Map<String, dynamic>)['following'] ??
                  [];

              if (following.isEmpty)
                return const SizedBox(
                  height: 300,
                  child: Center(child: Text("Follow someone to tag! 🤝")),
                );

              return DraggableScrollableSheet(
                initialChildSize: 0.7,
                minChildSize: 0.5,
                maxChildSize: 0.9,
                expand: false,
                builder: (_, controller) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15.0,
                        vertical: 10.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 50),
                          const Text(
                            "Tag Friends",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text(
                              "Done",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        controller: controller,
                        itemCount: following.length,
                        itemBuilder: (context, index) {
                          String friendId = following[index];

                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(friendId)
                                .get(),
                            builder: (context, userSnap) {
                              if (!userSnap.hasData || !userSnap.data!.exists)
                                return const SizedBox();
                              var data =
                                  userSnap.data!.data() as Map<String, dynamic>;
                              String friendName = data['username'] ?? 'User';

                              bool isSelected = _taggedUsers.any(
                                (user) => user['id'] == friendId,
                              );

                              return ListTile(
                                leading: SafeProfilePic(
                                  base64String: data['profilePic'] ?? '',
                                  radius: 20,
                                  fallbackText: friendName[0].toUpperCase(),
                                ),
                                title: Text(
                                  friendName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                trailing: Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  color: isSelected ? Colors.blue : Colors.grey,
                                ),
                                onTap: () {
                                  setModalState(() {
                                    if (isSelected) {
                                      _taggedUsers.removeWhere(
                                        (user) => user['id'] == friendId,
                                      );
                                    } else {
                                      _taggedUsers.add({
                                        'id': friendId,
                                        'username': friendName,
                                      });
                                    }
                                  });
                                  setState(() {});
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // 🌟 మ్యాజిక్: కెమెరా లేదా గ్యాలరీ ఆప్షన్ అడిగే మెనూ
  void _showPickerOptions({required bool isPost}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: Text(
                isPost ? "Add Photo" : "Add Video",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: Text(
                isPost ? "Take Photo (Camera)" : "Record Video (Camera)",
              ),
              onTap: () {
                Navigator.pop(ctx);
                if (isPost) {
                  _pickSingleImageFromCamera();
                } else {
                  _pickVideo(ImageSource.camera);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.purple),
              title: const Text("Choose from Gallery"),
              onTap: () {
                Navigator.pop(ctx);
                if (isPost) {
                  _pickAndCropImagesFromGallery();
                } else {
                  _pickVideo(ImageSource.gallery);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // 📸 కెమెరా నుండి సింగిల్ ఫోటో
  Future<void> _pickSingleImageFromCamera() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
    );

    if (pickedFile != null) {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.original,
            ],
          ),
        ],
      );
      if (croppedFile != null) {
        setState(() {
          _selectedImages = [File(croppedFile.path)];
        });
      }
    }
  }

  // 🖼️ గ్యాలరీ నుండి మల్టిపుల్ ఫోటోలు
  Future<void> _pickAndCropImagesFromGallery() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 100);

    if (pickedFiles.isNotEmpty) {
      List<File> croppedImages = [];
      for (var picked in pickedFiles) {
        CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: picked.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Image',
              toolbarColor: Colors.black,
              toolbarWidgetColor: Colors.white,
              aspectRatioPresets: [
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.original,
              ],
            ),
          ],
        );
        if (croppedFile != null) croppedImages.add(File(croppedFile.path));
      }
      setState(() => _selectedImages = croppedImages);
    }
  }

  // 🎥 కెమెరా లేదా గ్యాలరీ నుండి వీడియో
  Future<void> _pickVideo(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: source);
    if (pickedFile != null)
      setState(() => _selectedVideo = File(pickedFile.path));
  }

  void _triggerPostUpload() {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select an image first! 📸")),
      );
      return;
    }

    // 🌟 Upload start ayyindhani cheppadaniki
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Upload started in background... 🚀"),
        duration: Duration(seconds: 2),
      ),
    );

    UploadManager().backgroundUploadPost(
      _selectedImages,
      _postCaptionController.text.trim(),
      _isPostPublic,
      _taggedUsers.map((e) => e['id']!).toList(),
    );

    Navigator.pop(context); // Screen close chesthunnam
  }

  void _triggerReelUpload() {
    if (_selectedVideo == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Select a video first! 🎬")));
      return;
    }
    UploadManager().backgroundUploadReel(
      _selectedVideo!,
      _reelCaptionController.text.trim(),
      _isReelPublic,
      _taggedUsers.map((e) => e['id']!).toList(),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _postCaptionController.dispose();
    _reelCaptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "New Post",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            indicatorColor: Color(0xFFFD1D1D),
            labelColor: Color(0xFFFD1D1D),
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.grid_on), text: "POST"),
              Tab(icon: Icon(Icons.video_library), text: "REEL"),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildPostTab(isDark), _buildReelTab(isDark)],
        ),
      ),
    );
  }

  Widget _buildPostTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 🌟 ఇక్కడ ఆప్షన్స్ మెనూ ఓపెన్ అవుతుంది
          GestureDetector(
            onTap: () => _showPickerOptions(isPost: true),
            child: Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: _selectedImages.isNotEmpty
                  ? PageView.builder(
                      itemCount: _selectedImages.length,
                      itemBuilder: (ctx, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(
                          _selectedImages[i],
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 50,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 10),
                          Text(
                            "Tap to Add Photo",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _postCaptionController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: "Write a caption...",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.person_add_alt_1, color: Colors.blue),
            title: Text(
              _taggedUsers.isEmpty ? "Tag Friends" : "Tagged Friends:",
            ),
            subtitle: _taggedUsers.isNotEmpty
                ? Text(
                    _taggedUsers.map((e) => "@${e['username']}").join(", "),
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
            trailing: _taggedUsers.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => setState(() => _taggedUsers.clear()),
                  )
                : const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: _selectFriends,
          ),

          SwitchListTile(
            title: const Text("Public Post"),
            value: _isPostPublic,
            onChanged: (v) => setState(() => _isPostPublic = v),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF833AB4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _triggerPostUpload,
              child: const Text(
                "Share Post",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReelTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 🌟 ఇక్కడ ఆప్షన్స్ మెనూ ఓపెన్ అవుతుంది
          GestureDetector(
            onTap: () => _showPickerOptions(isPost: false),
            child: Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: _selectedVideo != null
                  ? const Center(
                      child: Icon(
                        Icons.check_circle,
                        size: 60,
                        color: Colors.green,
                      ),
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam_outlined,
                            size: 50,
                            color: Colors.blue,
                          ),
                          SizedBox(height: 10),
                          Text(
                            "Tap to Add Video",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _reelCaptionController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: "Reel caption...",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.person_add_alt_1, color: Colors.red),
            title: Text(
              _taggedUsers.isEmpty ? "Tag Friends" : "Tagged Friends:",
            ),
            subtitle: _taggedUsers.isNotEmpty
                ? Text(
                    _taggedUsers.map((e) => "@${e['username']}").join(", "),
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
            trailing: _taggedUsers.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => setState(() => _taggedUsers.clear()),
                  )
                : const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: _selectFriends,
          ),

          SwitchListTile(
            title: const Text("Public Reel"),
            value: _isReelPublic,
            onChanged: (v) => setState(() => _isReelPublic = v),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFD1D1D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _triggerReelUpload,
              child: const Text(
                "Share Reel",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
