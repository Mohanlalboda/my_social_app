import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FcmSenderService {
  // 🌟 .env నుండి టోకెన్ జనరేట్ చేసే మెథడ్
  static Future<String> _getAccessToken() async {
    final serviceAccountJson = {
      "type": "service_account",
      "project_id": dotenv.env['FIREBASE_PROJECT_ID'],
      "private_key_id": dotenv.env['FIREBASE_PRIVATE_KEY_ID'],
      "private_key": dotenv.env['FIREBASE_PRIVATE_KEY']?.replaceAll(
        r'\n',
        '\n',
      ),
      "client_email": dotenv.env['FIREBASE_CLIENT_EMAIL'],
      "client_id": dotenv.env['FIREBASE_CLIENT_ID'],
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url":
          "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url": dotenv.env['FIREBASE_CLIENT_X509_CERT_URL'],
      "universe_domain": "googleapis.com",
    };

    final accountCredentials = auth.ServiceAccountCredentials.fromJson(
      serviceAccountJson,
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

  static String get projectId => dotenv.env['FIREBASE_PROJECT_ID'] ?? "";

  // 1. సాధారణ నోటిఫికేషన్ (Likes, Comments, Follows)
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
      if (fcmToken == null || fcmToken.isEmpty) return;

      final accessToken = await _getAccessToken();
      final endpoint =
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': fcmToken,
            'notification': {'title': title, 'body': body},
            'android': {
              'priority': 'high',
              'notification': {
                'channel_id': 'super_high_importance_channel',
                'sound': 'default',
              },
            },
            'data': {'type': 'chat'},
          },
        }),
      );
    } catch (e) {
      debugPrint("❌ Notification Error: $e");
    }
  }

  // 2. కాలింగ్ నోటిఫికేషన్
  static Future<void> sendCallNotification({
    required String receiverId,
    required String callerName,
    required String callerPic,
    required String channelId,
    required bool isVideo,
    bool isGroupCall = false,
  }) async {
    try {
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .get();
      if (!userDoc.exists) return;
      String? fcmToken = userDoc.data()?['fcmToken'];
      if (fcmToken == null || fcmToken.isEmpty) return;

      final accessToken = await _getAccessToken();
      final endpoint =
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': fcmToken,
            'android': {'priority': 'high'},
            'data': {
              'type': 'call',
              'callerName': callerName,
              'callerPic': callerPic,
              'channelId': channelId,
              'isVideo': isVideo.toString(),
              'isGroupCall': isGroupCall.toString(),
            },
          },
        }),
      );
    } catch (e) {
      debugPrint("❌ Call Notification Error: $e");
    }
  }

  // 3. కాల్ ఎండ్ సిగ్నల్
  static Future<void> sendEndCallSignal({
    required String receiverId,
    required String channelId,
  }) async {
    try {
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .get();
      if (!userDoc.exists) return;
      String? fcmToken = userDoc.data()?['fcmToken'];
      if (fcmToken == null || fcmToken.isEmpty) return;

      final accessToken = await _getAccessToken();
      final endpoint =
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': fcmToken,
            'android': {'priority': 'high'},
            'data': {'type': 'end_call', 'channelId': channelId},
          },
        }),
      );
    } catch (e) {
      debugPrint("❌ End Call Error: $e");
    }
  }
}
