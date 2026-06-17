import 'package:cloud_firestore/cloud_firestore.dart';

class ReelModel {
  final String reelId;
  final String uid;
  final String username;
  final String videoUrl;
  final String caption;
  final DateTime timestamp;
  final List likes;

  ReelModel({
    required this.reelId,
    required this.uid,
    required this.username,
    required this.videoUrl,
    required this.caption,
    required this.timestamp,
    required this.likes,
  });

  factory ReelModel.fromSnap(DocumentSnapshot snap) {
    var snapshot = snap.data() as Map<String, dynamic>;

    // 🌟 THE FIX: Safe Timestamp Parsing for Offline Support
    var timeData = snapshot['timestamp'] ?? snapshot['datePublished'];
    DateTime safeDate = DateTime.now();

    if (timeData is Timestamp) {
      safeDate = timeData.toDate();
    } else if (timeData is String) {
      safeDate = DateTime.tryParse(timeData) ?? DateTime.now();
    }

    return ReelModel(
      reelId: snapshot['reelId'] ?? '',
      uid: snapshot['uid'] ?? '',
      username: snapshot['username'] ?? 'User',
      videoUrl: snapshot['videoUrl'] ?? '',
      caption: snapshot['caption'] ?? '',
      timestamp: safeDate,
      likes: snapshot['likes'] ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    "reelId": reelId,
    "uid": uid,
    "username": username,
    "videoUrl": videoUrl,
    "caption": caption,
    "timestamp": timestamp,
    "likes": likes,
  };
}
