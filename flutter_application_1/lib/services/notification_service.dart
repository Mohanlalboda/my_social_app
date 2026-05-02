import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'fcm_sender_service.dart';
import '../screens/chat/call_screen.dart'; //

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (message.data['type'] == 'call') {
    await PushNotificationService.showCallkitIncoming(message.data);
  } else if (message.data['type'] == 'end_call') {
    String? channelId = message.data['channelId'];
    if (channelId != null) {
      await FlutterCallkitIncoming.endCall(channelId);
    }
    await FlutterCallkitIncoming.endAllCalls();
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class PushNotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    String? token = await _fcm.getToken();
    if (token != null) _saveTokenToDatabase(token);
    _fcm.onTokenRefresh.listen(_saveTokenToDatabase);

    const InitializationSettings initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _localNotificationsPlugin.initialize(settings: initSettings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'super_high_importance_channel',
      'Chat Notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['type'] == 'call') {
        showCallkitIncoming(message.data);
        return;
      } else if (message.data['type'] == 'end_call') {
        String? channelId = message.data['channelId'];
        if (channelId != null) FlutterCallkitIncoming.endCall(channelId);
        FlutterCallkitIncoming.endAllCalls();
        return;
      }

      if (message.notification != null) {
        _localNotificationsPlugin.show(
          id: message.notification.hashCode,
          title: message.notification!.title,
          body: message.notification!.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              color: const Color(0xFF00E5FF),
            ),
          ),
        );
      }
    });

    // 🌟 THE FIX 3: కాల్ లిఫ్ట్ చేసినా, కట్ చేసినా రియాక్ట్ అయ్యే లాజిక్
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
      if (event == null) return;

      // 🟢 1. కాల్ లిఫ్ట్ చేసినప్పుడు (Accept)
      if (event.event == Event.actionCallAccept) {
        try {
          var extra = event.body['extra'];
          if (extra != null) {
            String channelId = extra['channelId'] ?? '';
            bool isVideo =
                extra['isVideo'] == true || extra['isVideo'] == 'true';
            bool isGroupCall =
                extra['isGroupCall'] == true || extra['isGroupCall'] == 'true';

            // స్టేటస్ అప్‌డేట్
            await FirebaseFirestore.instance
                .collection('calls')
                .doc(channelId)
                .set({'status': 'accepted'}, SetOptions(merge: true));

            // 🌟 యాప్ ఎక్కడున్నా సరే డైరెక్ట్ గా కాలింగ్ స్క్రీన్ కి తీసుకెళ్తున్నాం!
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => CallScreen(
                  channelName: channelId,
                  isVideoCall: isVideo,
                  isGroupCall: isGroupCall,
                ),
              ),
            );
          }
        } catch (e) {
          debugPrint("❌ Accept Error: $e");
        }
      }
      // 🔴 2. కాల్ కట్ చేసినప్పుడు (Decline)
      else if (event.event == Event.actionCallDecline) {
        try {
          var extra = event.body['extra'];
          String? channelId = extra != null ? extra['channelId'] : null;
          bool isGroupCall = extra != null
              ? (extra['isGroupCall'] == true || extra['isGroupCall'] == 'true')
              : false;

          if (channelId != null) {
            if (!isGroupCall) {
              await FirebaseFirestore.instance
                  .collection('calls')
                  .doc(channelId)
                  .set({'status': 'declined'}, SetOptions(merge: true));
              var callDoc = await FirebaseFirestore.instance
                  .collection('calls')
                  .doc(channelId)
                  .get();
              if (callDoc.exists) {
                String callerId = callDoc.data()?['callerId'] ?? '';
                if (callerId.isNotEmpty) {
                  FcmSenderService.sendEndCallSignal(
                    receiverId: callerId,
                    channelId: channelId,
                  );
                }
              }
            }
          }
        } catch (e) {
          debugPrint("❌ Decline Error: $e");
        }
      }
    });
  }

  static Future<void> showCallkitIncoming(Map<String, dynamic> data) async {
    final String callId = data['channelId'] ?? 'unknown_call_id';
    bool isVideo = data['isVideo'] == 'true';
    bool isGroupCall = data['isGroupCall'] == 'true'; // 🌟 డేటా తీసుకుంటున్నాం

    final params = CallKitParams(
      id: callId,
      nameCaller: data['callerName'] ?? 'Unknown',
      appName: 'MyBanjara',
      avatar: data['callerPic'] ?? '',
      handle: isVideo ? 'Incoming Video Call...' : 'Incoming Voice Call...',
      type: isVideo ? 1 : 0,
      duration: 30000,
      textAccept: 'Accept',
      textDecline: 'Decline',
      extra: <String, dynamic>{
        'channelId': data['channelId'],
        'isVideo': isVideo,
        'isGroupCall': isGroupCall, // 🌟 పాస్ చేస్తున్నాం
      },
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0955fa',
        actionColor: '#4CAF50',
        textColor: '#ffffff',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  static void _saveTokenToDatabase(String token) async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    }
  }
}
