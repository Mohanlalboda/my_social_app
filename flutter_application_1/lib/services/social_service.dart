import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class SocialService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🌟 1. పోస్ట్/రీల్ లైక్ లాజిక్
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

  // 🌟 2. స్టోరీ (Story) లైక్ లాజిక్ & నోటిఫికేషన్ (NEW)
  static Future<void> toggleStoryLike({
    required String storyId,
    required String ownerId,
    required List likesArray,
  }) async {
    String currentUid = FirebaseAuth.instance.currentUser!.uid;
    try {
      if (likesArray.contains(currentUid)) {
        await _firestore.collection('stories').doc(storyId).update({
          'likes': FieldValue.arrayRemove([currentUid]),
        });
      } else {
        await _firestore.collection('stories').doc(storyId).update({
          'likes': FieldValue.arrayUnion([currentUid]),
        });

        // 🔔 నోటిఫికేషన్ పంపడం
        if (currentUid != ownerId) {
          await _firestore.collection('users').doc(ownerId).collection('notifications').add({
            'type': 'story_like',
            'senderId': currentUid,
            'storyId': storyId,
            'isRead': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint("Error story like: $e");
    }
  }

  // 🌟 3. సేవ్/అన్‌సేవ్ లాజిక్
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

  // 🌟 4. క్లీన్ అప్ (పాత స్టోరీస్ డిలీట్)
  static Future<void> cleanupOldMoments() async {
    try {
      DateTime yesterday = DateTime.now().subtract(const Duration(hours: 24));
      var oldMomentsSnap = await _firestore.collection('stories').where('expiresAt', isLessThan: yesterday).get();
      for (var doc in oldMomentsSnap.docs) {
        String mediaUrl = doc.data()['storyUrl'] ?? '';
        if (mediaUrl.isNotEmpty) {
          try {
            await FirebaseStorage.instance.refFromURL(mediaUrl).delete();
          } catch (e) { debugPrint("Storage Delete Error: $e"); }
        }
        await doc.reference.delete();
      }
      debugPrint("✅ Old stories cleaned!");
    } catch (e) { debugPrint("Cleanup Error: $e"); }
  }
}