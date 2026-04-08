// ignore_for_file: depend_on_referenced_packages, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';

class UploadManager {
  // ఇది Singleton క్లాస్
  static final UploadManager _instance = UploadManager._internal();
  factory UploadManager() => _instance;
  UploadManager._internal();

  final ValueNotifier<bool> isUploading = ValueNotifier(false);
  final ValueNotifier<double> uploadProgress = ValueNotifier(0.0);
  final ValueNotifier<String> uploadStatus = ValueNotifier("");

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🗜️ 1. ఇమేజ్ కంప్రెషన్
  Future<File> compressImage(File file) async {
    uploadStatus.value = "Compressing Image... 🗜️";
    final tempDir = await getTemporaryDirectory();
    final path = tempDir.path;
    int rand = DateTime.now().millisecondsSinceEpoch;
    String targetPath = "$path/img_$rand.jpg";

    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70, // 🌟 60 నుండి 70 కి మార్చాను, క్వాలిటీ బాగుంటుంది
    );
    return File(result!.path);
  }

  // 🗜️ 2. వీడియో కంప్రెషన్
  Future<File> compressVideo(File file) async {
    uploadStatus.value = "Compressing Video... ⏳";
    MediaInfo? mediaInfo = await VideoCompress.compressVideo(
      file.path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
      includeAudio: true,
    );
    return File(mediaInfo!.file!.path);
  }

  // ☁️ 3. స్టోరేజ్ లోకి ఎక్కించడం
  Future<String> uploadFileToStorage(
    String childName,
    File file,
    bool isVideo,
    String id,
  ) async {
    try {
      Reference ref = _storage
          .ref()
          .child(childName)
          .child(FirebaseAuth.instance.currentUser!.uid)
          .child(id);

      UploadTask uploadTask = ref.putFile(file);
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        uploadProgress.value = progress;
        uploadStatus.value =
            "Uploading to Cloud... ☁️ ${(progress * 100).toStringAsFixed(0)}%";
      });

      TaskSnapshot snap = await uploadTask;
      String downloadUrl = await snap.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception("Storage Upload Error: $e");
    }
  }

  // 🚀 4. ఫైనల్ అప్‌లోడ్ ఫంక్షన్ (ఇక్కడే మ్యాజిక్ జరుగుతుంది)
  Future<bool> uploadMedia({
    required File file,
    required String caption,
    required bool isVideo,
    required bool isReel,
    double? latitude, // 🌟 లొకేషన్ పారామీటర్
    double? longitude, // 🌟 లొకేషన్ పారామీటర్
  }) async {
    isUploading.value = true;
    uploadProgress.value = 0.0;

    try {
      uploadStatus.value = "1. Start అవుతోంది... ⏳";
      String uid = FirebaseAuth.instance.currentUser!.uid;
      String postId = const Uuid().v1();

      uploadStatus.value = "2. File రెడీ చేస్తున్నాం... 📁";
      if (!await file.exists()) {
        throw Exception("ఫైల్ దొరకలేదు!");
      }

      // 🌟 కంప్రెషన్
      File compressedFile;
      if (isVideo) {
        compressedFile = await compressVideo(file);
      } else {
        compressedFile = await compressImage(file);
      }

      String folderName = 'posts';

      uploadStatus.value = "3. Storage కి వెళ్తోంది... ☁️";
      String mediaUrl = await uploadFileToStorage(
        folderName,
        compressedFile,
        isVideo,
        postId,
      );

      uploadStatus.value = "4. Saving to Database... ✍️";

      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      var userData = userDoc.data() as Map<String, dynamic>;

      Map<String, dynamic> postData = {
        'postId': postId,
        'ownerId': uid,
        'username': userData['username'],
        'profilePic': userData['profilePic'],
        'postData': [mediaUrl],
        'caption': caption,
        'type': isVideo ? 'video' : 'image',
        'isReel': isReel,
        'likes': [],
        'savedBy': [],
        'commentCount': 0,
        'isPublic': userData['isPublic'] ?? true,
        'timestamp': FieldValue.serverTimestamp(),
        // 🌟 THE FIX: డేటాబేస్ లోకి లొకేషన్ వెళ్లేలా ఇక్కడ యాడ్ చేశాను
        'latitude': latitude,
        'longitude': longitude,
      };

      await _firestore.collection('posts').doc(postId).set(postData);

      uploadStatus.value = "5. Success! 🎉";
      await Future.delayed(const Duration(seconds: 2));

      isUploading.value = false;
      return true;
    } catch (e) {
      uploadStatus.value = "❌ Error: $e";
      isUploading.value = false;
      return false;
    }
  }

  // 🌟 5. Auto Reel కోసం స్పెషల్ అప్‌లోడ్ ఫంక్షన్
  Future<void> backgroundUploadAutoReel({
    required List<File> images,
    required String caption,
    required bool isLocalAudio,
    String? localAudioPath,
    required String trendingAudioUrl,
  }) async {
    isUploading.value = true;
    uploadStatus.value = "Preparing Auto Reel... 🎞️";
    uploadProgress.value = 0.0;

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      String postId = const Uuid().v1();
      List<String> imageUrls = [];

      for (int i = 0; i < images.length; i++) {
        uploadStatus.value = "Compressing Image ${i + 1}/${images.length}...";
        File compressed = await compressImage(images[i]);

        uploadStatus.value = "Uploading Image ${i + 1}/${images.length}...";
        String url = await uploadFileToStorage(
          'auto_reels/$postId',
          compressed,
          false,
          'img_$i.jpg',
        );
        imageUrls.add(url);
        uploadProgress.value = (i + 1) / images.length;
      }

      uploadStatus.value = "Uploading Audio... 🎵";

      String finalAudioUrl = trendingAudioUrl;
      if (isLocalAudio && localAudioPath != null) {
        File audioFile = File(localAudioPath);
        String ext = audioFile.path.split('.').last;
        Reference ref = _storage.ref().child(
          'audio/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext',
        );
        UploadTask uploadTask = ref.putFile(audioFile);
        finalAudioUrl = await (await uploadTask).ref.getDownloadURL();
      }

      uploadStatus.value = "Finalizing Auto Reel... ✍️";

      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      var userData = userDoc.data() as Map<String, dynamic>;

      await _firestore.collection('posts').doc(postId).set({
        'postId': postId,
        'ownerId': uid,
        'username': userData['username'],
        'profilePic': userData['profilePic'],
        'postData': imageUrls,
        'audioUrl': finalAudioUrl,
        'isLocalAudio': isLocalAudio,
        'caption': caption,
        'type': 'auto_reel',
        'isReel': true,
        'likes': [],
        'savedBy': [],
        'commentCount': 0,
        'isPublic': userData['isPublic'] ?? true,
        'timestamp': FieldValue.serverTimestamp(),
      });

      uploadStatus.value = "Auto Reel Ready! 🎉";
      await Future.delayed(const Duration(milliseconds: 500));

      isUploading.value = false;
    } catch (e) {
      debugPrint("Auto Reel Upload Error: $e");
      isUploading.value = false;
    }
  }

  // 🌟 6. Moments కోసం
  Future<void> uploadMoment(File file, bool isVideo) async {
    isUploading.value = true;
    uploadStatus.value = "Uploading Moment... ✨";
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      String momentId = const Uuid().v1();

      File compressedFile;
      if (isVideo) {
        compressedFile = await compressVideo(file);
      } else {
        compressedFile = await compressImage(file);
      }

      String url = await uploadFileToStorage(
        'moments',
        compressedFile,
        isVideo,
        momentId,
      );

      DateTime expiry = DateTime.now().add(const Duration(hours: 24));

      await _firestore.collection('moments').doc(momentId).set({
        'momentId': momentId,
        'ownerId': uid,
        'mediaUrl': url,
        'type': isVideo ? 'video' : 'image',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiry),
        'viewers': [],
        'likes': [],
      });
      isUploading.value = false;
    } catch (e) {
      debugPrint("Moment Error: $e");
      isUploading.value = false;
    }
  }
}
