import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FcmSenderService {
  // 🌟 మీ ఒరిజినల్ JSON కోడ్ ఇక్కడ ఉంచండి
  static const String _serviceAccountJsonString = r'''
{
  "type": "service_account",
  "project_id": "my-social-app-d3394",
  "private_key_id": "a452d0b0d2d1cd8d3884d2a9cfaca621a53c2f74",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDgaC8A1DXOkSTg\nYwKt3IwA8UiRptMW03d1AvH501Z7IVisIS6QOjO8rFFfOXBhi/KBkWzAl/EoCjgy\nOVxtV/G4xU4Xhee24iOAnPEnnGWQefuAo7U0lVOFfxre0Y8WeRfw8BFTazMrUkCe\nKITgouDHs0ABCBFZ5QRIYT70gPQVbwOLAJar1wv/Awr4011OeSbPGyOfYbzbf6lD\nfqMF3n5yX3yjL+pKTXohA1AoMcc2ItrkR7MOMmwKswzOK7SmEukwZPmDoG88wxnC\n8UBNtWOfYGvKtftRhys3cWWXTN6xLDHgPW/JQzB1UgpUA2bU5sofUm9hiDO3UPed\nV/2dWYM/AgMBAAECggEAEP1s+u6WKPljOzEz2DmiSJtRUmRjh08OXx0QeJ4wENV2\n/bKWGxRVAMa5HcZfBFD7VM+lALXgQRb4/JB24iPDk34uCejjoLyL/JD6pHRFBO8U\nrr92Q4YUvemK0sOMm6J3wLr5oiuzwua7frNJpX+fbhnbpthXW/YotgQq0d8w263D\niEdp6boaoSB6kdto3Nhz5ATNoP8MXLFcmMwndJZ1F9VVA2BygZ1IRUGOA6UybAZg\n3zD/rHynEc0YN9nbDS6ZoxNuoNc/Tm0WY7qLXxd49rRE1pRxO2vgZg5Mn53oXiOU\nGCsTRuMBfZT2C4ruvN1uEI5KpikEIpn6KDoFt1SDNQKBgQD3FKMVax7Mn7bMAwb6\niTkCG5P2+cfNjxA84QjfSdtKRIvqe3rRJl7OtMHg73oSnWfgtZngO4MRH70QwbGH\nDojpTgJNi9kz+NK25gXFN/u9S4qws3ZGf8HtS8g56bgdQRhnCw4NIaphM3en1Qv2\nr4xQkfkwoUVlGIEosg45szLYwwKBgQDoggLT0kyn8OhBa1ju66v0JPSmHiHvT9rN\nDfzrNVtrgcppjqOfXfx8SjimSaNZJMiWD5d/u1s4Ssm3T7V0seVLqqSxVjXBTkn/\nOkGpwvw+8zsKrp6JcdN9thIGnLm5MGD/wVsP+Ar8Bw5IFpxPE3wVTlnywXtqhbJr\nvJPvM22j1QKBgDA9BDX7SvESQYMFGEizn8Csl6/BRmP4iWgJW00Uw051oYdvAiRx\nRFNA8RU0S/X0a0Jw0hD4LXebZbMuzbUbfllmVIbFReuiqajxsbC2ZFypsfMbpnzP\nFpJ4mCfOXJbBjb0YaG7h4rzFapgGvSY1UcStKyR2Z/D73sOON77GIKg3AoGAS/76\nx5uMXLQ8Ze2dcvJrEPDnWkitFNiIDtAMpCCbkgcpTtlFl/iTZ1inLYsSLjf8rDfK\ncACgL0Uaq6UNDWh8JwBOtnwUM+vP+fFjtwY5hqXf3Xz36rrews85Exo1BlfOzKm5\nhv2vMXNo8p0ZWCtpOlmSwusE2Ot8RwSrYdrwckUCgYBtAafmEciuAetKtCOnxqm2\nNXtt690gx6rMgbnF1w+HJitno+2zHYzADRV9pizS4yz03PMrZpsyoHZqdIYT+JOM\naHy4eqeamvBo9OkP/CtCpcQx1evfhWJw/rRf83x+Lga8zYrZXoFh7Zyi30SVnNqG\niU1mw1wbe2VeuGd9kQW0Jg==\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-fbsvc@my-social-app-d3394.iam.gserviceaccount.com",
  "client_id": "116094628904711043089",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40my-social-app-d3394.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com"
}
''';

  static Future<String> _getAccessToken() async {
    final accountCredentials = auth.ServiceAccountCredentials.fromJson(
      _serviceAccountJsonString,
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

  // 💬 1. మామూలు చాట్ మెసేజెస్ పంపడానికి
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

      final jsonData = jsonDecode(_serviceAccountJsonString);
      final accessToken = await _getAccessToken();
      final endpoint =
          'https://fcm.googleapis.com/v1/projects/${jsonData['project_id']}/messages:send';

      await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': fcmToken,
            'notification': {
              'title': title,
              'body': body,
            }, // మామూలు పాప్-అప్ వస్తుంది
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
      debugPrint("❌ Chat Notification Error: $e");
    }
  }

  // 📞 2. కాలింగ్ వస్తే స్క్రీన్ మోగించడానికి స్పెషల్ ఫంక్షన్
  static Future<void> sendCallNotification({
    required String receiverId,
    required String callerName,
    required String callerPic,
    required String channelId,
    required bool isVideo,
    bool isGroupCall =
        false, // 🌟 THE FIX: ఇది గ్రూప్ కాలా కదా అని తెలుసుకోవడానికి
  }) async {
    try {
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .get();
      if (!userDoc.exists) return;
      String? fcmToken = userDoc.data()?['fcmToken'];
      if (fcmToken == null || fcmToken.isEmpty) return;

      final jsonData = jsonDecode(_serviceAccountJsonString);
      final accessToken = await _getAccessToken();
      final endpoint =
          'https://fcm.googleapis.com/v1/projects/${jsonData['project_id']}/messages:send';

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
              'isGroupCall': isGroupCall.toString(), // 🌟 డేటా పంపుతున్నాం
            },
          },
        }),
      );
    } catch (e) {
      debugPrint("❌ Call Notification Error: $e");
    }
  }

  // 🚫 కాల్ కట్ చేసినప్పుడు అవతలి ఫోన్ లో రింగ్ ఆపడానికి సిగ్నల్!
  static Future<void> sendEndCallSignal({
    required String receiverId,
    required String channelId, // 🌟 ఏ కాల్ కట్ చేయాలో ఐడీ అడుగుతున్నాం
  }) async {
    try {
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .get();
      if (!userDoc.exists) return;
      String? fcmToken = userDoc.data()?['fcmToken'];
      if (fcmToken == null || fcmToken.isEmpty) return;

      final jsonData = jsonDecode(_serviceAccountJsonString);
      final accessToken = await _getAccessToken();
      final endpoint =
          'https://fcm.googleapis.com/v1/projects/${jsonData['project_id']}/messages:send';

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
              'type': 'end_call',
              'channelId': channelId, // 🌟 ఐడీ ని పంపుతున్నాం!
            },
          },
        }),
      );
    } catch (e) {
      debugPrint("❌ End Call Error: $e");
    }
  }
}
