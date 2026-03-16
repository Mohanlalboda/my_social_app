import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // debugPrint కోసం
import 'package:uuid/uuid.dart'; // 🌟 UUID కోసం ఇక్కడ ఇంపోర్ట్ చేశాం

class ReelService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // వీడియోని స్టోరేజ్‌కి అప్‌లోడ్ చేసే ఫంక్షన్
  Future<String> uploadVideoToStorage(String reelId, File videoFile) async {
    Reference ref = _storage.ref().child('reels').child(reelId);
    UploadTask uploadTask = ref.putFile(videoFile);
    TaskSnapshot snap = await uploadTask;
    String downloadUrl = await snap.ref.getDownloadURL();
    return downloadUrl;
  }

  // ఫైర్‌స్టోర్‌లో రీల్ డీటెయిల్స్ సేవ్ చేయడం
  Future<String> postReel(String caption, File videoFile) async {
    String res = "Some error occurred";
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      // 🌟 MAGIC FIX: uuid ని ఇక్కడ ఇలా వాడాలి
      String reelId = const Uuid().v1();

      // 1. వీడియో అప్‌లోడ్ చేసి URL తెచ్చుకోవడం
      String videoUrl = await uploadVideoToStorage(reelId, videoFile);

      // 2. ఫైర్‌స్టోర్‌లో డేటా సేవ్ చేయడం
      await _firestore.collection('reels').doc(reelId).set({
        'uid': uid,
        'username': 'User', // ప్రస్తుతానికి డమ్మీ, తర్వాత మార్చుకోవచ్చు
        'reelId': reelId,
        'videoUrl': videoUrl,
        'caption': caption,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
      });

      res = "success";
    } catch (e) {
      // 🌟 print కి బదులు debugPrint వాడటం మంచిది
      debugPrint("🚨 Error uploading reel: ${e.toString()}");
      res = e.toString();
    }
    return res;
  }
}
