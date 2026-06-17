// lib/main.dart
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 🌟 Import Added

import 'screens/home/post_detail_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'firebase_options_dev.dart';
import 'firebase_options_prod.dart';
import 'screens/main_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

StreamSubscription<Uri>? _globalLinkSubscription;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🌟 .env ఫైల్ ని లోడ్ చేస్తున్నాం
  await dotenv.load(fileName: ".env");

  await MobileAds.instance.initialize();

  const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');

  FirebaseOptions options;
  if (flavor == 'prod') {
    options = ProdFirebaseOptions.currentPlatform;
  } else {
    options = DevFirebaseOptions.currentPlatform;
  }

  await Firebase.initializeApp(options: options);

  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  _initGlobalDeepLinks();

  runApp(const MyApp());
}

void _initGlobalDeepLinks() {
  final appLinks = AppLinks();
  appLinks.getInitialLink().then((uri) {
    if (uri != null) {
      _handleGlobalDeepLink(uri);
    }
  });

  _globalLinkSubscription = appLinks.uriLinkStream.listen((uri) {
    _handleGlobalDeepLink(uri);
  });
}

void _handleGlobalDeepLink(Uri uri) {
  if (uri.path == '/share') {
    String? postId = uri.queryParameters['id'];
    String? type = uri.queryParameters['type'];

    if (postId != null && type != null) {
      if (FirebaseAuth.instance.currentUser != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(postId: postId, type: type),
          ),
        );
      }
    }
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    _globalLinkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'MyBanjara',
          theme: ThemeData(
            brightness: Brightness.light,
            fontFamily: GoogleFonts.poppins().fontFamily,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            fontFamily: GoogleFonts.poppins().fontFamily,
          ),
          themeMode: mode,
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return const MainScreen();
              }
              return const WelcomeScreen();
            },
          ),
        );
      },
    );
  }
}
