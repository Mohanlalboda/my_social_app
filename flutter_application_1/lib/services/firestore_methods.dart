// lib/services/firestore_methods.dart

import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart'; // 🌟 THE FIX: For temp directory
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

List<String> extractHashtags(String caption) {
  RegExp exp = RegExp(r"\#\w+");
  Iterable<Match> matches = exp.allMatches(caption);
  return matches.map((m) => m.group(0)!.toLowerCase()).toList();
}

class FirestoreMethods {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==========================================
  // 🗜️ COMPRESSION HELPERS (DATA SAVERS!)
  // ==========================================

  // 1. Post Images కోసం (80% డేటా సేవ్)
  Future<Uint8List?> _compressImage(File file) async {
    return await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 800,
      minHeight: 800,
      quality: 60, // 🌟 80% డేటా సేవ్ అవుతుంది
    );
  }

  // 2. Chat, Profile & Story Images కోసం (File లాగా రిటర్న్ చేస్తుంది)
  Future<File> _compressImageFile(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      var result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 60, // 🌟 Aggressive compression for data saving
        minWidth: 800,
        minHeight: 800,
      );
      return result != null ? File(result.path) : file;
    } catch (e) {
      return file;
    }
  }

  // 3. Videos (Reels & Stories) కోసం
  Future<File?> _compressVideo(File file) async {
    final MediaInfo? info = await VideoCompress.compressVideo(
      file.path,
      quality: VideoQuality.MediumQuality, // 🌟 బ్యాలెన్స్డ్ క్వాలిటీ
      deleteOrigin: false,
    );
    return info?.file;
  }

  // ==========================================
  // 📤 STORIES, POSTS, REELS UPLOAD
  // ==========================================

  Future<String> uploadStory(
    File? mediaFile,
    String storyType,
    String textContent, {
    String privacy = 'everyone',
  }) async {
    try {
      String uid = _auth.currentUser!.uid;
      String storyId = const Uuid().v1();
      String downloadUrl = "";

      // 🌟 .get() is fine here (No streams needed for quick fetch)
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String username = userData['username'] ?? userData['name'] ?? 'User';
      String profilePic = userData['profilePic'] ?? '';
      String userVillage = userData['village'] ?? '';

      if (mediaFile != null) {
        File finalMediaFile = mediaFile;

        // 🌟 THE FIX: వీడియో & ఫోటో కంప్రెషన్ ఫర్ స్టోరీస్
        if (storyType == "video") {
          finalMediaFile = await _compressVideo(mediaFile) ?? mediaFile;
        } else if (storyType == "image") {
          finalMediaFile = await _compressImageFile(mediaFile);
        }

        String folder = storyType == "video"
            ? "story_videos"
            : (storyType == "voice" ? "story_voices" : "stories");

        TaskSnapshot snap = await _storage
            .ref()
            .child(folder)
            .child(uid)
            .child(storyId)
            .putFile(finalMediaFile); // కంప్రెస్డ్ ఫైల్ అప్‌లోడ్

        downloadUrl = await snap.ref.getDownloadURL();
      }

      await _firestore.collection('stories').doc(storyId).set({
        'storyId': storyId,
        'uid': uid,
        'username': username,
        'profilePic': profilePic,
        'storyUrl': downloadUrl,
        'textContent': textContent,
        'type': storyType,
        'timestamp': FieldValue.serverTimestamp(),
        'datePublished': FieldValue.serverTimestamp(),
        'viewers': [],
        'privacy': privacy,
        'village': userVillage,
      });
      return "success";
    } catch (e) {
      return e.toString();
    }
  }

  Future<String> uploadAudioPost(String caption, File audioFile) async {
    try {
      String uid = _auth.currentUser!.uid;
      String postId = const Uuid().v1();
      TaskSnapshot snap = await _storage
          .ref()
          .child('post_audios')
          .child(postId)
          .putFile(audioFile);
      String audioUrl = await snap.ref.getDownloadURL();
      var userData =
          (await _firestore.collection('users').doc(uid).get()).data()
              as Map<String, dynamic>;

      await _firestore.collection('posts').doc(postId).set({
        'uid': uid,
        'username': userData['username'] ?? 'User',
        'profilePic': userData['profilePic'] ?? '',
        'postId': postId,
        'postUrl': audioUrl,
        'description': caption,
        'hashtags': extractHashtags(caption),
        'timestamp': FieldValue.serverTimestamp(),
        'datePublished': FieldValue.serverTimestamp(),
        'likes': [],
        'savedBy': [],
        'type': 'audio',
        'village': userData['village'] ?? '',
      });
      return "success";
    } catch (e) {
      return e.toString();
    }
  }

  Future<String> uploadPost(String caption, List<File> imageFiles) async {
    try {
      String uid = _auth.currentUser!.uid;
      String postId = const Uuid().v1();
      List<String> postUrls = [];

      for (int i = 0; i < imageFiles.length; i++) {
        // 🌟 కంప్రెస్ అయిన ఇమేజ్ మాత్రమే వెళ్తుంది
        Uint8List? compressedImage = await _compressImage(imageFiles[i]);
        if (compressedImage != null) {
          TaskSnapshot snap = await _storage
              .ref()
              .child('posts')
              .child(postId)
              .child('image_$i')
              .putData(compressedImage);
          postUrls.add(await snap.ref.getDownloadURL());
        }
      }
      var userData =
          (await _firestore.collection('users').doc(uid).get()).data()
              as Map<String, dynamic>;

      await _firestore.collection('posts').doc(postId).set({
        'uid': uid,
        'username': userData['username'] ?? 'User',
        'profilePic': userData['profilePic'] ?? '',
        'postId': postId,
        'postUrls': postUrls,
        'postUrl': postUrls.isNotEmpty ? postUrls.first : '',
        'description': caption,
        'hashtags': extractHashtags(caption),
        'timestamp': FieldValue.serverTimestamp(),
        'datePublished': FieldValue.serverTimestamp(),
        'likes': [],
        'savedBy': [],
        'type': 'image',
        'village': userData['village'] ?? '',
      });
      return "success";
    } catch (e) {
      return e.toString();
    }
  }

  Future<String> uploadReel(String caption, File videoFile) async {
    try {
      String uid = _auth.currentUser!.uid;
      String reelId = const Uuid().v1();

      // 🌟 వీడియో కంప్రెషన్
      File finalVideo = await _compressVideo(videoFile) ?? videoFile;

      TaskSnapshot snap = await _storage
          .ref()
          .child('reels')
          .child(reelId)
          .putFile(finalVideo);
      String videoUrl = await snap.ref.getDownloadURL();

      String thumbnailUrl = "";
      try {
        final uint8list = await VideoThumbnail.thumbnailData(
          video: finalVideo.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 400,
          quality: 75,
        );
        if (uint8list != null) {
          TaskSnapshot thumbSnap = await _storage
              .ref()
              .child('reels_thumbnails')
              .child(reelId)
              .putData(uint8list);
          thumbnailUrl = await thumbSnap.ref.getDownloadURL();
        }
      } catch (e) {
        debugPrint("Error generating thumbnail: $e");
      }

      var userData =
          (await _firestore.collection('users').doc(uid).get()).data()
              as Map<String, dynamic>;

      await _firestore.collection('reels').doc(reelId).set({
        'uid': uid,
        'username': userData['username'] ?? 'User',
        'reelId': reelId,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'caption': caption,
        'hashtags': extractHashtags(caption),
        'village': userData['village'] ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'datePublished': FieldValue.serverTimestamp(),
        'likes': [],
        'savedBy': [],
      });
      return "success";
    } catch (err) {
      return err.toString();
    }
  }

  // ==========================================
  // ❤️ LIKES, COMMENTS, SAVES & FOLLOWS
  // ==========================================

  Future<void> likePost(String postId, String uid, List likes) async {
    try {
      if (likes.contains(uid))
        await _firestore.collection('posts').doc(postId).update({
          'likes': FieldValue.arrayRemove([uid]),
        });
      else
        await _firestore.collection('posts').doc(postId).update({
          'likes': FieldValue.arrayUnion([uid]),
        });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> likeReel(String reelId, String uid, List likes) async {
    try {
      if (likes.contains(uid))
        await _firestore.collection('reels').doc(reelId).update({
          'likes': FieldValue.arrayRemove([uid]),
        });
      else
        await _firestore.collection('reels').doc(reelId).update({
          'likes': FieldValue.arrayUnion([uid]),
        });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> likeStory(String storyId, String uid) async {
    try {
      var snap = await _firestore.collection('stories').doc(storyId).get();
      List likes = snap.data()?['likes'] ?? [];
      if (likes.contains(uid))
        await _firestore.collection('stories').doc(storyId).update({
          'likes': FieldValue.arrayRemove([uid]),
        });
      else
        await _firestore.collection('stories').doc(storyId).update({
          'likes': FieldValue.arrayUnion([uid]),
        });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<String> postComment(
    String postId,
    String text,
    String uid,
    String name,
    String profilePic,
  ) async {
    try {
      if (text.trim().isNotEmpty) {
        String commentId = DateTime.now().millisecondsSinceEpoch.toString();
        await _firestore
            .collection('posts')
            .doc(postId)
            .collection('comments')
            .doc(commentId)
            .set({
              'profilePic': profilePic,
              'name': name,
              'uid': uid,
              'text': text.trim(),
              'commentId': commentId,
              'datePublished': FieldValue.serverTimestamp(),
            });
        return "success";
      }
      return "Empty";
    } catch (e) {
      return e.toString();
    }
  }

  Future<String> postReelComment(
    String reelId,
    String text,
    String uid,
    String name,
    String profilePic,
  ) async {
    try {
      if (text.trim().isNotEmpty) {
        String commentId = DateTime.now().millisecondsSinceEpoch.toString();
        await _firestore
            .collection('reels')
            .doc(reelId)
            .collection('comments')
            .doc(commentId)
            .set({
              'profilePic': profilePic,
              'name': name,
              'uid': uid,
              'text': text.trim(),
              'commentId': commentId,
              'datePublished': FieldValue.serverTimestamp(),
            });
        return "success";
      }
      return "Empty";
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> followUser(String currentUid, String followId) async {
    try {
      var snap = await _firestore.collection('users').doc(currentUid).get();
      List following = snap.data()?['following'] ?? [];
      if (following.contains(followId)) {
        await _firestore.collection('users').doc(followId).update({
          'followers': FieldValue.arrayRemove([currentUid]),
        });
        await _firestore.collection('users').doc(currentUid).update({
          'following': FieldValue.arrayRemove([followId]),
        });
      } else {
        await _firestore.collection('users').doc(followId).update({
          'followers': FieldValue.arrayUnion([currentUid]),
        });
        await _firestore.collection('users').doc(currentUid).update({
          'following': FieldValue.arrayUnion([followId]),
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> savePost(String postId, String uid, List savedBy) async {
    try {
      if (savedBy.contains(uid))
        await _firestore.collection('posts').doc(postId).update({
          'savedBy': FieldValue.arrayRemove([uid]),
        });
      else
        await _firestore.collection('posts').doc(postId).update({
          'savedBy': FieldValue.arrayUnion([uid]),
        });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> saveReel(String reelId, String uid, List savedBy) async {
    try {
      if (savedBy.contains(uid))
        await _firestore.collection('reels').doc(reelId).update({
          'savedBy': FieldValue.arrayRemove([uid]),
        });
      else
        await _firestore.collection('reels').doc(reelId).update({
          'savedBy': FieldValue.arrayUnion([uid]),
        });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<String> deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();
      return "success";
    } catch (e) {
      return e.toString();
    }
  }

  Future<String> deleteReel(String reelId) async {
    try {
      await _firestore.collection('reels').doc(reelId).delete();
      return "success";
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> deleteExpiredStories() async {
    try {
      final DateTime twentyFourHoursAgo = DateTime.now().subtract(
        const Duration(hours: 24),
      );
      QuerySnapshot oldStories = await _firestore
          .collection('stories')
          .where('timestamp', isLessThan: twentyFourHoursAgo)
          .get();
      for (var doc in oldStories.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  // ==========================================
  // 💬 CHAT METHODS & MESSAGES (1-TO-1)
  // ==========================================

  // 🌟 THE FIX: Pagination Limit Added
  Stream<QuerySnapshot> getMessages(
    String currentUid,
    String receiverUid, {
    int limit = 50,
  }) {
    List<String> ids = [currentUid, receiverUid];
    ids.sort();
    String chatRoomId = ids.join("_");

    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit) // 🌟 50 మెసేజ్ లు మాత్రమే లోడ్ అవుతాయి (డేటా సేవింగ్)
        .snapshots();
  }

  Future<void> markMessageAsRead(String chatRoomId) async {
    try {
      String currentUid = _auth.currentUser!.uid;
      var unreadMsgs = await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUid)
          .where('status', isNotEqualTo: 'read')
          .get(); // 🌟 Using get() instead of streams for efficiency
      for (var doc in unreadMsgs.docs) {
        await doc.reference.update({'status': 'read'});
      }
      await _firestore.collection('chat_rooms').doc(chatRoomId).update({
        'isRead': true,
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> sendMessage(
    String receiverId,
    String message, {
    bool isVanish = false,
  }) async {
    try {
      String currentUid = _auth.currentUser!.uid;
      String messageId = DateTime.now().millisecondsSinceEpoch.toString();
      List<String> ids = [currentUid, receiverId];
      ids.sort();
      String chatRoomId = ids.join("_");

      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .set({
            'senderId': currentUid,
            'receiverId': receiverId,
            'message': message,
            'messageType': 'text',
            'messageId': messageId,
            'isVanish': isVanish,
            'status': 'sent',
            'timestamp': FieldValue.serverTimestamp(),
            'deletedFor': [],
          });
      await _firestore.collection('chat_rooms').doc(chatRoomId).set({
        'chatRoomId': chatRoomId,
        'users': ids,
        'lastMessage': isVanish ? '👻 Vanish Message' : message,
        'lastMessageSender': currentUid,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> sendReplyMessage({
    required String receiverId,
    required String message,
    required Map<String, dynamic> repliedToData,
    bool isVanish = false,
  }) async {
    try {
      String currentUid = _auth.currentUser!.uid;
      String messageId = DateTime.now().millisecondsSinceEpoch.toString();
      List<String> ids = [currentUid, receiverId];
      ids.sort();
      String chatRoomId = ids.join("_");

      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .set({
            'senderId': currentUid,
            'receiverId': receiverId,
            'message': message,
            'messageType': 'text',
            'messageId': messageId,
            'isVanish': isVanish,
            'status': 'sent',
            'repliedTo': repliedToData,
            'timestamp': FieldValue.serverTimestamp(),
            'deletedFor': [],
          });
      await _firestore.collection('chat_rooms').doc(chatRoomId).update({
        'lastMessage': message,
        'lastMessageSender': currentUid,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> sendImageMessage(
    String receiverId,
    File imageFile, {
    bool isVanish = false,
  }) async {
    try {
      String currentUid = _auth.currentUser!.uid;
      String messageId = DateTime.now().millisecondsSinceEpoch.toString();
      List<String> ids = [currentUid, receiverId];
      ids.sort();
      String chatRoomId = ids.join("_");

      // 🌟 THE FIX: Chat Image Compression
      File compressedImage = await _compressImageFile(imageFile);

      String imageUrl =
          await (await _storage
                  .ref()
                  .child('chat_images')
                  .child(chatRoomId)
                  .child(messageId)
                  .putFile(compressedImage))
              .ref
              .getDownloadURL();

      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .set({
            'senderId': currentUid,
            'receiverId': receiverId,
            'message': imageUrl,
            'messageType': 'image',
            'messageId': messageId,
            'isVanish': isVanish,
            'status': 'sent',
            'timestamp': FieldValue.serverTimestamp(),
            'deletedFor': [],
          });
      await _firestore.collection('chat_rooms').doc(chatRoomId).update({
        'lastMessage': '📷 Image',
        'lastMessageSender': currentUid,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> sendVoiceMessage(
    String receiverId,
    File audioFile, {
    bool isVanish = false,
  }) async {
    try {
      String currentUid = _auth.currentUser!.uid;
      String messageId = DateTime.now().millisecondsSinceEpoch.toString();
      List<String> ids = [currentUid, receiverId];
      ids.sort();
      String chatRoomId = ids.join("_");

      String audioUrl =
          await (await _storage
                  .ref()
                  .child('chat_voices')
                  .child(chatRoomId)
                  .child(messageId)
                  .putFile(audioFile))
              .ref
              .getDownloadURL();

      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .set({
            'senderId': currentUid,
            'receiverId': receiverId,
            'message': audioUrl,
            'messageType': 'audio',
            'messageId': messageId,
            'isVanish': isVanish,
            'status': 'sent',
            'timestamp': FieldValue.serverTimestamp(),
            'deletedFor': [],
          });
      await _firestore.collection('chat_rooms').doc(chatRoomId).update({
        'lastMessage': '🎤 Voice Note',
        'lastMessageSender': currentUid,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> sendDocumentMessage(
    String receiverId,
    File docFile,
    String fileName, {
    bool isVanish = false,
  }) async {
    try {
      String currentUid = _auth.currentUser!.uid;
      String messageId = DateTime.now().millisecondsSinceEpoch.toString();
      List<String> ids = [currentUid, receiverId];
      ids.sort();
      String chatRoomId = ids.join("_");

      String fileUrl =
          await (await _storage
                  .ref()
                  .child('chat_docs')
                  .child(chatRoomId)
                  .child(messageId)
                  .putFile(docFile))
              .ref
              .getDownloadURL();

      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .set({
            'senderId': currentUid,
            'receiverId': receiverId,
            'message': fileUrl,
            'fileName': fileName,
            'messageType': 'document',
            'messageId': messageId,
            'isVanish': isVanish,
            'status': 'sent',
            'timestamp': FieldValue.serverTimestamp(),
            'deletedFor': [],
          });
      await _firestore.collection('chat_rooms').doc(chatRoomId).update({
        'lastMessage': '📄 Document',
        'lastMessageSender': currentUid,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> sendLocationMessage(
    String receiverId,
    double lat,
    double lng, {
    bool isVanish = false,
  }) async {
    try {
      String currentUid = _auth.currentUser!.uid;
      String messageId = DateTime.now().millisecondsSinceEpoch.toString();
      List<String> ids = [currentUid, receiverId];
      ids.sort();
      String chatRoomId = ids.join("_");

      String mapsUrl =
          "https://www.google.com/maps/search/?api=1&query=$lat,$lng";

      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .set({
            'senderId': currentUid,
            'receiverId': receiverId,
            'message': mapsUrl,
            'messageType': 'location',
            'messageId': messageId,
            'isVanish': isVanish,
            'status': 'sent',
            'timestamp': FieldValue.serverTimestamp(),
            'deletedFor': [],
          });
      await _firestore.collection('chat_rooms').doc(chatRoomId).update({
        'lastMessage': '📍 Location',
        'lastMessageSender': currentUid,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> deleteMessage(
    String chatRoomId,
    String messageId,
    bool isLastMessage, {
    bool forEveryone = false,
  }) async {
    try {
      String currentUid = _auth.currentUser!.uid;
      if (forEveryone) {
        await _firestore
            .collection('chat_rooms')
            .doc(chatRoomId)
            .collection('messages')
            .doc(messageId)
            .delete();
        if (isLastMessage)
          await _firestore.collection('chat_rooms').doc(chatRoomId).update({
            'lastMessage': '🚫 Message deleted',
          });
      } else {
        await _firestore
            .collection('chat_rooms')
            .doc(chatRoomId)
            .collection('messages')
            .doc(messageId)
            .update({
              'deletedFor': FieldValue.arrayUnion([currentUid]),
            });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> clearChatMessages(String chatRoomId) async {
    try {
      String currentUid = _auth.currentUser!.uid;
      var messages = await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .get();
      for (var doc in messages.docs) {
        await doc.reference.update({
          'deletedFor': FieldValue.arrayUnion([currentUid]),
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> updateMessageReaction(
    String chatRoomId,
    String messageId,
    String reaction,
  ) async {
    try {
      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .update({'reaction': reaction});
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> updateTypingStatus(String chatRoomId, bool isTyping) async {
    try {
      await _firestore.collection('chat_rooms').doc(chatRoomId).set({
        'typingStatus': {_auth.currentUser!.uid: isTyping},
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> toggleVanishMode(String chatRoomId, bool isVanish) async {
    try {
      await _firestore.collection('chat_rooms').doc(chatRoomId).set({
        'isVanishMode': isVanish,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> cleanVanishMessages(String chatRoomId) async {
    try {
      var msgs = await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .where('isVanish', isEqualTo: true)
          .get();
      for (var doc in msgs.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> updateChatTheme(String chatRoomId, String themeName) async {
    try {
      await _firestore.collection('chat_rooms').doc(chatRoomId).set({
        'chatTheme': themeName,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> togglePinChat(String chatRoomId, bool currentPinStatus) async {
    try {
      await _firestore.collection('chat_rooms').doc(chatRoomId).set({
        'isPinned': !currentPinStatus,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<bool> shareMediaToChat({
    required String receiverId,
    required String mediaId,
    required String mediaUrl,
    required String senderUsername,
    bool isReel = false,
  }) async {
    try {
      String currentUid = _auth.currentUser!.uid;
      String messageId = DateTime.now().millisecondsSinceEpoch.toString();
      List<String> ids = [currentUid, receiverId];
      ids.sort();
      String chatRoomId = ids.join("_");

      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .set({
            'senderId': currentUid,
            'receiverId': receiverId,
            'message': mediaUrl,
            'messageType': isReel ? 'shared_reel' : 'shared_post',
            'mediaId': mediaId,
            'messageId': messageId,
            'isVanish': false,
            'status': 'sent',
            'timestamp': FieldValue.serverTimestamp(),
            'deletedFor': [],
          });
      await _firestore.collection('chat_rooms').doc(chatRoomId).set({
        'chatRoomId': chatRoomId,
        'users': ids,
        'lastMessage': isReel ? '🎬 Shared a Reel' : '📸 Shared a Post',
        'lastMessageSender': currentUid,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint("Error: $e");
      return false;
    }
  }

  Future<void> updateActiveStatus(bool isOnline) async {
    try {
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> saveBubbleNote(String noteText) async {
    try {
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'bubbleNote': noteText,
        'bubbleNoteTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> deleteBubbleNote() async {
    try {
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'bubbleNote': FieldValue.delete(),
        'bubbleNoteTime': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> updateUserLocation(double latitude, double longitude) async {
    try {
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'latitude': latitude,
        'longitude': longitude,
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  // ==========================================
  // 👨‍👩‍👧‍👦 GROUP CHAT METHODS
  // ==========================================

  Future<bool> createGroupChat({
    required String groupName,
    required List<String> memberIds,
    required String groupPic,
  }) async {
    try {
      String groupId = const Uuid().v1();
      String currentUid = _auth.currentUser!.uid;

      await _firestore.collection('chat_rooms').doc(groupId).set({
        'chatRoomId': groupId,
        'groupName': groupName,
        'groupPic': groupPic,
        'users': memberIds,
        'admins': [currentUid],
        'createdBy': currentUid,
        'isGroup': true,
        'isCommunity': false,
        'timestamp': FieldValue.serverTimestamp(),
        'lastMessage': 'Group Created 🎉',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint("Error creating group: $e");
      return false;
    }
  }

  Future<bool> updateGroupProfilePic(String groupId, File imageFile) async {
    try {
      // 🌟 THE FIX: Group Profile Pic Compression
      File compressedImage = await _compressImageFile(imageFile);

      String imageUrl =
          await (await _storage
                  .ref()
                  .child('group_pics')
                  .child(groupId)
                  .putFile(compressedImage))
              .ref
              .getDownloadURL();

      await _firestore.collection('chat_rooms').doc(groupId).update({
        'groupPic': imageUrl,
      });
      return true;
    } catch (e) {
      debugPrint("Error: $e");
      return false;
    }
  }

  Future<void> removeUserFromGroup(String groupId, String uidToRemove) async {
    try {
      await _firestore.collection('chat_rooms').doc(groupId).update({
        'users': FieldValue.arrayRemove([uidToRemove]),
        'admins': FieldValue.arrayRemove([uidToRemove]),
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> sendGroupMessage(String groupId, String message) async {
    try {
      String messageId = const Uuid().v1();
      String currentUid = _auth.currentUser!.uid;

      await _firestore
          .collection('chat_rooms')
          .doc(groupId)
          .collection('messages')
          .doc(messageId)
          .set({
            'senderId': currentUid,
            'message': message,
            'messageType': 'text',
            'messageId': messageId,
            'timestamp': FieldValue.serverTimestamp(),
            'deletedFor': [],
            'reaction': '',
          });
      await _firestore.collection('chat_rooms').doc(groupId).update({
        'lastMessage': message,
        'lastMessageSender': currentUid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> sendGroupReplyMessage({
    required String groupId,
    required String message,
    required Map<String, dynamic> repliedToData,
  }) async {
    try {
      String messageId = const Uuid().v1();
      String currentUid = _auth.currentUser!.uid;

      await _firestore
          .collection('chat_rooms')
          .doc(groupId)
          .collection('messages')
          .doc(messageId)
          .set({
            'senderId': currentUid,
            'message': message,
            'messageType': 'text',
            'repliedTo': repliedToData,
            'messageId': messageId,
            'timestamp': FieldValue.serverTimestamp(),
            'deletedFor': [],
            'reaction': '',
          });
      await _firestore.collection('chat_rooms').doc(groupId).update({
        'lastMessage': message,
        'lastMessageSender': currentUid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> sendGroupImageMessage(String groupId, File imageFile) async {
    try {
      String messageId = const Uuid().v1();
      String currentUid = _auth.currentUser!.uid;

      // 🌟 THE FIX: Group Image Compression
      File compressedImage = await _compressImageFile(imageFile);

      String imageUrl =
          await (await _storage
                  .ref()
                  .child('group_images')
                  .child(groupId)
                  .child(messageId)
                  .putFile(compressedImage))
              .ref
              .getDownloadURL();

      await _firestore
          .collection('chat_rooms')
          .doc(groupId)
          .collection('messages')
          .doc(messageId)
          .set({
            'senderId': currentUid,
            'message': imageUrl,
            'messageType': 'image',
            'messageId': messageId,
            'timestamp': FieldValue.serverTimestamp(),
            'deletedFor': [],
            'reaction': '',
          });
      await _firestore.collection('chat_rooms').doc(groupId).update({
        'lastMessage': '📷 Image',
        'lastMessageSender': currentUid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> sendGroupVoiceMessage(String groupId, File audioFile) async {
    try {
      String messageId = const Uuid().v1();
      String currentUid = _auth.currentUser!.uid;
      String audioUrl =
          await (await _storage
                  .ref()
                  .child('group_voices')
                  .child(groupId)
                  .child(messageId)
                  .putFile(audioFile))
              .ref
              .getDownloadURL();

      await _firestore
          .collection('chat_rooms')
          .doc(groupId)
          .collection('messages')
          .doc(messageId)
          .set({
            'senderId': currentUid,
            'message': audioUrl,
            'messageType': 'audio',
            'messageId': messageId,
            'timestamp': FieldValue.serverTimestamp(),
            'deletedFor': [],
            'reaction': '',
          });
      await _firestore.collection('chat_rooms').doc(groupId).update({
        'lastMessage': '🎤 Voice Note',
        'lastMessageSender': currentUid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> sendGroupDocumentMessage(
    String groupId,
    File docFile,
    String fileName,
  ) async {
    try {
      String messageId = const Uuid().v1();
      String currentUid = _auth.currentUser!.uid;
      String fileUrl =
          await (await _storage
                  .ref()
                  .child('group_docs')
                  .child(groupId)
                  .child(messageId)
                  .putFile(docFile))
              .ref
              .getDownloadURL();

      await _firestore
          .collection('chat_rooms')
          .doc(groupId)
          .collection('messages')
          .doc(messageId)
          .set({
            'senderId': currentUid,
            'message': fileUrl,
            'fileName': fileName,
            'messageType': 'document',
            'messageId': messageId,
            'timestamp': FieldValue.serverTimestamp(),
            'deletedFor': [],
            'reaction': '',
          });
      await _firestore.collection('chat_rooms').doc(groupId).update({
        'lastMessage': '📄 Document',
        'lastMessageSender': currentUid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> sendGroupLocationMessage(
    String groupId,
    double lat,
    double lng,
  ) async {
    try {
      String messageId = const Uuid().v1();
      String currentUid = _auth.currentUser!.uid;
      String mapsUrl =
          "https://www.google.com/maps/search/?api=1&query=$lat,$lng";

      await _firestore
          .collection('chat_rooms')
          .doc(groupId)
          .collection('messages')
          .doc(messageId)
          .set({
            'senderId': currentUid,
            'message': mapsUrl,
            'messageType': 'location',
            'messageId': messageId,
            'timestamp': FieldValue.serverTimestamp(),
            'deletedFor': [],
            'reaction': '',
          });
      await _firestore.collection('chat_rooms').doc(groupId).update({
        'lastMessage': '📍 Location',
        'lastMessageSender': currentUid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> updateGroupMessageReaction(
    String groupId,
    String messageId,
    String reaction,
  ) async {
    try {
      await _firestore
          .collection('chat_rooms')
          .doc(groupId)
          .collection('messages')
          .doc(messageId)
          .update({'reaction': reaction});
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> deleteGroupMessage(
    String groupId,
    String messageId,
    bool isLastMessage, {
    bool forEveryone = false,
  }) async {
    try {
      String currentUid = _auth.currentUser!.uid;
      if (forEveryone) {
        await _firestore
            .collection('chat_rooms')
            .doc(groupId)
            .collection('messages')
            .doc(messageId)
            .delete();
        if (isLastMessage)
          await _firestore.collection('chat_rooms').doc(groupId).update({
            'lastMessage': '🚫 Message deleted',
          });
      } else {
        await _firestore
            .collection('chat_rooms')
            .doc(groupId)
            .collection('messages')
            .doc(messageId)
            .update({
              'deletedFor': FieldValue.arrayUnion([currentUid]),
            });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> sendGroupEmergencyMessage(String groupId, String message) async {
    try {
      String messageId = const Uuid().v1();
      String currentUid = _auth.currentUser!.uid;

      await _firestore
          .collection('chat_rooms')
          .doc(groupId)
          .collection('messages')
          .doc(messageId)
          .set({
            'senderId': currentUid,
            'message': message,
            'messageType': 'emergency',
            'messageId': messageId,
            'timestamp': FieldValue.serverTimestamp(),
            'deletedFor': [],
            'reaction': '',
          });
      await _firestore.collection('chat_rooms').doc(groupId).update({
        'lastMessage': '🚨 Emergency Alert',
        'lastMessageSender': currentUid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> sendGroupPoll(
    String groupId,
    String question,
    List<String> options,
  ) async {
    try {
      String messageId = const Uuid().v1();
      String currentUid = _auth.currentUser!.uid;

      List<Map<String, dynamic>> formattedOptions = options
          .map((opt) => {'option': opt, 'votes': []})
          .toList();

      await _firestore
          .collection('chat_rooms')
          .doc(groupId)
          .collection('messages')
          .doc(messageId)
          .set({
            'senderId': currentUid,
            'message': question,
            'messageType': 'poll',
            'options': formattedOptions,
            'messageId': messageId,
            'timestamp': FieldValue.serverTimestamp(),
            'deletedFor': [],
            'reaction': '',
          });
      await _firestore.collection('chat_rooms').doc(groupId).update({
        'lastMessage': '📊 Poll: $question',
        'lastMessageSender': currentUid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> voteOnPoll(
    String groupId,
    String messageId,
    int optionIndex,
  ) async {
    try {
      String currentUid = _auth.currentUser!.uid;
      DocumentReference msgRef = _firestore
          .collection('chat_rooms')
          .doc(groupId)
          .collection('messages')
          .doc(messageId);

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(msgRef);
        if (!snapshot.exists) return;
        List<dynamic> options = snapshot['options'];

        for (var opt in options) {
          (opt['votes'] as List).remove(currentUid);
        }
        (options[optionIndex]['votes'] as List).add(currentUid);

        transaction.update(msgRef, {'options': options});
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> pinGroupMessage(String groupId, String messageText) async {
    try {
      await _firestore.collection('chat_rooms').doc(groupId).update({
        'pinnedMessage': messageText,
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> toggleAdminOnlyMode(String groupId, bool isRestricted) async {
    try {
      await _firestore.collection('chat_rooms').doc(groupId).update({
        'isAdminOnly': isRestricted,
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  // ==========================================
  // 🌟 HIGHLIGHTS METHODS
  // ==========================================

  Future<String> createHighlight(
    String title,
    File coverImage,
    List<File> highlightMedias,
  ) async {
    String res = "Some error occurred";
    try {
      String uid = _auth.currentUser!.uid;
      String highlightId = const Uuid().v1();
      Reference coverRef = _storage
          .ref()
          .child('highlights')
          .child(uid)
          .child(highlightId)
          .child('cover');
      await coverRef.putFile(coverImage);
      String coverUrl = await coverRef.getDownloadURL();
      List<String> mediaUrls = [];
      for (int i = 0; i < highlightMedias.length; i++) {
        Reference mediaRef = _storage
            .ref()
            .child('highlights')
            .child(uid)
            .child(highlightId)
            .child('media_$i');
        await mediaRef.putFile(highlightMedias[i]);
        mediaUrls.add(await mediaRef.getDownloadURL());
      }
      await _firestore.collection('highlights').doc(highlightId).set({
        'highlightId': highlightId,
        'uid': uid,
        'name': title,
        'coverUrl': coverUrl,
        'mediaUrls': mediaUrls,
        'timestamp': FieldValue.serverTimestamp(),
      });
      res = "success";
    } catch (e) {
      res = e.toString();
      debugPrint("Error: $e");
    }
    return res;
  }

  Future<void> addActiveStoryToHighlight(
    String highlightId,
    String storyUrl,
  ) async {
    try {
      await _firestore.collection('highlights').doc(highlightId).update({
        'mediaUrls': FieldValue.arrayUnion([storyUrl]),
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }
}
