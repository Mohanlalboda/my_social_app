import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 🌟 THE FIX: kDebugMode కోసం ఇది కచ్చితంగా ఉండాలి
import 'package:google_mobile_ads/google_mobile_ads.dart';

class MyNativeAdWidget extends StatefulWidget {
  const MyNativeAdWidget({super.key});

  @override
  State<MyNativeAdWidget> createState() => _MyNativeAdWidgetState();
}

class _MyNativeAdWidgetState extends State<MyNativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();

    _nativeAd = NativeAd(
      // 🌟 THE FIX: టెస్టింగ్ అప్పుడు టెస్ట్ యాడ్, ప్రొడక్షన్ లో రియల్ యాడ్
      adUnitId: kDebugMode
          ? 'ca-app-pub-3940256099942544/2247696110' // ఇది టెస్ట్ ఐడీ
          : 'ca-app-pub-7426724746409466/5274632733', // 👈 ఇది మీ రియల్ Native ID
      factoryId: 'adFactoryExample', // MainActivity.kt లో మనం పెట్టిన పేరు
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() => _isLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Native Ad failed to load: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose(); // 🌟 మెమరీ లీక్ అవ్వకుండా యాడ్ ని డిస్పోజ్ చేయాలి
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return _isLoaded
        ? Container(
            height: 320, // యాడ్ కి సరిపడా ప్లేస్
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.all(8),
            color: isDark ? Colors.grey[900] : Colors.grey[100],
            child: AdWidget(ad: _nativeAd!),
          )
        : const SizedBox(); // లోడ్ అయ్యేలోపు ఏమీ చూపించదు (సైలెంట్ గా ఉంటుంది)
  }
}
