import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SocialService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🌟 1. లైక్/అన్‌లైక్ లాజిక్
  static Future<void> toggleLike({
    required String postId,
    required List likesArray,
    required bool isReel,
  }) async {
    String currentUid = FirebaseAuth.instance.currentUser!.uid;
    String collection = isReel ? 'reels' : 'posts';

    try {
      if (likesArray.contains(currentUid)) {
        await _firestore.collection(collection).doc(postId).update({
          'likes': FieldValue.arrayRemove([currentUid]),
        });
      } else {
        await _firestore.collection(collection).doc(postId).update({
          'likes': FieldValue.arrayUnion([currentUid]),
        });
      }
    } catch (e) {
      debugPrint("Error updating like: $e");
    }
  }

  // 🌟 2. సేవ్/అన్‌సేవ్ లాజిక్
  static Future<void> toggleSave({
    required String postId,
    required List savedArray,
    required bool isReel,
  }) async {
    String currentUid = FirebaseAuth.instance.currentUser!.uid;
    String collection = isReel ? 'reels' : 'posts';

    try {
      if (savedArray.contains(currentUid)) {
        await _firestore.collection(collection).doc(postId).update({
          'savedBy': FieldValue.arrayRemove([currentUid]),
        });
      } else {
        await _firestore.collection(collection).doc(postId).update({
          'savedBy': FieldValue.arrayUnion([currentUid]),
        });
      }
    } catch (e) {
      debugPrint("Error updating save: $e");
    }
  }
}
