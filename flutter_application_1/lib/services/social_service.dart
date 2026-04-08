import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

  // 🌟 3. 24 గంటలు దాటిన స్టోరీలను ఆటోమేటిక్‌గా డిలీట్ చేసే ఫంక్షన్
  static Future<void> cleanupOldMoments() async {
    try {
      // 24 గంటల క్రితం టైమ్ (నిన్నటి టైమ్)
      DateTime yesterday = DateTime.now().subtract(const Duration(hours: 24));

      // నిన్నటికంటే పాతవైన (24 గంటలు దాటిన) స్టోరీల కోసం వెతుకుతున్నాం
      var oldMomentsSnap = await _firestore
          .collection('moments')
          .where('timestamp', isLessThan: yesterday)
          .get();

      for (var doc in oldMomentsSnap.docs) {
        var data = doc.data();
        String mediaUrl = data['mediaUrl'] ?? '';

        // 1. ముందు ఫైర్‌బేస్ స్టోరేజ్ నుండి ఫోటో/వీడియో డిలీట్ చేయాలి
        if (mediaUrl.isNotEmpty) {
          try {
            Reference storageRef = FirebaseStorage.instance.refFromURL(
              mediaUrl,
            );
            await storageRef.delete();
          } catch (e) {
            debugPrint("Storage Delete Error: $e");
          }
        }

        // 2. ఆ తర్వాత ఫైర్‌స్టోర్ (డేటాబేస్) నుండి ఆ డాక్యుమెంట్ డిలీట్ చేయాలి
        await doc.reference.delete();
      }

      debugPrint("✅ 24 hours పాత స్టోరీలన్నీ డిలీట్ అయిపోయాయి!");
    } catch (e) {
      debugPrint("Cleanup Error: $e");
    }
  }
}
