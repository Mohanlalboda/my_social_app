import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String senderId;
  final String receiverId;
  final String message;
  final String messageId;
  final DateTime timestamp;

  MessageModel({
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.messageId,
    required this.timestamp,
  });

  factory MessageModel.fromSnap(DocumentSnapshot snap) {
    var snapshot = snap.data() as Map<String, dynamic>;

    // 🌟 THE FIX: Safe Timestamp Parsing for Offline Support
    var timeData = snapshot['timestamp'];
    DateTime safeDate = DateTime.now();

    if (timeData is Timestamp) {
      safeDate = timeData.toDate();
    } else if (timeData is String) {
      safeDate = DateTime.tryParse(timeData) ?? DateTime.now();
    }

    return MessageModel(
      senderId: snapshot['senderId'] ?? '',
      receiverId: snapshot['receiverId'] ?? '',
      message: snapshot['message'] ?? '',
      messageId: snapshot['messageId'] ?? '',
      timestamp: safeDate,
    );
  }

  Map<String, dynamic> toJson() => {
    'senderId': senderId,
    'receiverId': receiverId,
    'message': message,
    'messageId': messageId,
    'timestamp': timestamp,
  };
}
