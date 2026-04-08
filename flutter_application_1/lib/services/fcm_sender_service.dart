import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FcmSenderService {
  static Future<String> _getAccessToken() async {
    final jsonString = await rootBundle.loadString(
      'assets/service_account.json',
    );
    final accountCredentials = auth.ServiceAccountCredentials.fromJson(
      jsonString,
    );
    final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
    final client = await auth.clientViaServiceAccount(
      accountCredentials,
      scopes,
    );
    final accessToken = client.credentials.accessToken.data;
    client.close();
    return accessToken;
  }

  static Future<void> sendNotification({
    required String receiverId,
    required String title,
    required String body,
  }) async {
    try {
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .get();
      if (!userDoc.exists) return;

      String? fcmToken = userDoc.data()?['fcmToken'];
      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint("User has no FCM token yet.");
        return;
      }

      final jsonString = await rootBundle.loadString(
        'assets/service_account.json',
      );
      final jsonData = jsonDecode(jsonString);
      final projectId = jsonData['project_id'];
      final accessToken = await _getAccessToken();

      final endpoint =
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': fcmToken,
            'notification': {'title': title, 'body': body},
            'data': {
              'type': 'chat',
              'senderId': FirebaseAuth.instance.currentUser?.uid ?? '',
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("✅ Notification Sent Successfully!");
      } else {
        debugPrint("❌ Failed to send notification: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Error sending push notification: $e");
    }
  }
}
