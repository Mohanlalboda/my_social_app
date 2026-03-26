import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// యాప్ క్లోజ్ చేసి ఉన్నప్పుడు నోటిఫికేషన్స్ రావడానికి (ఇది పైన బయటే ఉండాలి)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Background Message Received: ${message.messageId}");
}

class PushNotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // 1. నోటిఫికేషన్స్ పంపడానికి పర్మిషన్ అడగడం
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint("✅ Notifications Permission Granted!");
    }

    // 2. డివైజ్ టోకెన్ (ఈ మొబైల్ కి ఒక ఐడీ లాంటిది) తీసుకొని ఫైర్‌బేస్‌లో సేవ్ చేయడం
    String? token = await _fcm.getToken();
    if (token != null) {
      debugPrint("🔥 FCM Token: $token");
      _saveTokenToDatabase(token);
    }

    // 3. టోకెన్ ఎప్పుడైనా మారితే అప్‌డేట్ చేయడం
    _fcm.onTokenRefresh.listen(_saveTokenToDatabase);

    // 4. లోకల్ నోటిఫికేషన్స్ సెటప్
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
    );

    // 🌟 FIX 1: లేటెస్ట్ ప్యాకేజీ ప్రకారం 'initializationSettings:' అని యాడ్ చేశాం
    await _localNotifications.initialize(
      settings: initSettings, // 🌟 లేటెస్ట్ ప్యాకేజీకి కావాల్సింది ఇదే!
    );
    // 5. బ్యాక్‌గ్రౌండ్ మెసేజెస్ ని వినడం
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 6. ఫర్‌గ్రౌండ్ (యాప్ వాడుతున్నప్పుడు) మెసేజెస్ వస్తే చూపించడం
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });
  }

  // 🌟 ఫైర్‌బేస్ లో యూజర్ ప్రొఫైల్ లో టోకెన్ సేవ్ చేయడం
  static void _saveTokenToDatabase(String token) async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    }
  }

  // 🌟 మొబైల్ పైన నోటిఫికేషన్ పాపప్ చూపించే డిజైన్
  static void _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    // 🌟 FIX 2: లేటెస్ట్ ప్యాకేజీ ప్రకారం 'id:', 'title:', 'body:', 'notificationDetails:' అని యాడ్ చేశాం
    await _localNotifications.show(
      id: message.hashCode,
      title: message.notification?.title,
      body: message.notification?.body,
      notificationDetails: platformDetails,
    );
  }
}
