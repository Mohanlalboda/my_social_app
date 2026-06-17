import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String postId;
  final String uid;
  final String username;
  final String profilePic;
  final String postUrl;
  final String description;
  final DateTime datePublished;
  final List likes;

  PostModel({
    required this.postId,
    required this.uid,
    required this.username,
    required this.profilePic,
    required this.postUrl,
    required this.description,
    required this.datePublished,
    required this.likes,
  });

  factory PostModel.fromSnap(DocumentSnapshot snap) {
    var snapshot = snap.data() as Map<String, dynamic>;

    // 🌟 THE FIX: Safe Timestamp Parsing for Offline Support
    var timeData = snapshot['datePublished'] ?? snapshot['timestamp'];
    DateTime safeDate = DateTime.now();

    if (timeData is Timestamp) {
      safeDate = timeData.toDate();
    } else if (timeData is String) {
      safeDate = DateTime.tryParse(timeData) ?? DateTime.now();
    }

    return PostModel(
      postId: snapshot['postId'] ?? snapshot['id'] ?? '',
      uid: snapshot['uid'] ?? snapshot['ownerId'] ?? '',
      username: snapshot['username'] ?? '',
      profilePic: snapshot['profilePic'] ?? '',
      postUrl: snapshot['postUrl'] ?? '',
      description: snapshot['description'] ?? snapshot['caption'] ?? '',
      datePublished: safeDate,
      likes: snapshot['likes'] ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    "postId": postId,
    "uid": uid,
    "username": username,
    "profilePic": profilePic,
    "postUrl": postUrl,
    "description": description,
    "datePublished": datePublished,
    "likes": likes,
  };
}
