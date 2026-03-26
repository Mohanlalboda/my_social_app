import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart'; // 🌟 ఈ లైన్ యాడ్ చేయండి
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FcmSenderService {
  // 🌟 గూగుల్ నుండి సీక్రెట్ యాక్సెస్ టోకెన్ తెచ్చుకోవడం
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

  // 🌟 అసలైన నోటిఫికేషన్ సెండ్ చేసే ఫంక్షన్
  static Future<void> sendNotification({
    required String receiverId,
    required String title,
    required String body,
  }) async {
    try {
      // 1. అవతలి వాళ్ళ మొబైల్ టోకెన్ (fcmToken) ఫైర్‌బేస్ నుండి తెచ్చుకోవడం
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .get();
      if (!userDoc.exists) return;

      String? fcmToken = userDoc.data()?['fcmToken'];
      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint("ఈ యూజర్ కి ఇంకా టోకెన్ లేదు");
        return;
      }

      // 2. మన JSON కీ నుండి Project ID మరియు Access Token తెచ్చుకోవడం
      final jsonString = await rootBundle.loadString(
        'assets/service_account.json',
      );
      final jsonData = jsonDecode(jsonString);
      final projectId = jsonData['project_id'];
      final accessToken = await _getAccessToken();

      // 3. ఫైర్‌బేస్ కి నోటిఫికేషన్ పంపమని రిక్వెస్ట్ కొట్టడం
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
              'type':
                  'chat', // నోటిఫికేషన్ క్లిక్ చేస్తే చాట్ ఓపెన్ అవ్వడానికి వాడతాం
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
