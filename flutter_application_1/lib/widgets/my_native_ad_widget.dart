// lib/widgets/my_native_ad_widget.dart

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class MyNativeAdWidget extends StatefulWidget {
  const MyNativeAdWidget({super.key});

  @override
  State<MyNativeAdWidget> createState() => _MyNativeAdWidgetState();
}

class _MyNativeAdWidgetState extends State<MyNativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;

  // 🔴 REAL ID (మీ రియల్ యాడ్స్ వస్తాయి)
  final String nativeAdId = 'ca-app-pub-7426724746409466/5274632733';

  @override
  void initState() {
    super.initState();

    _nativeAd = NativeAd(
      adUnitId: nativeAdId,
      factoryId:
          'adFactoryExample', // Android లో MainActivity.java లో దీన్ని సెటప్ చేయాలి
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
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return _isLoaded
        ? Container(
            height: 320,
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.all(8),
            color: isDark ? Colors.grey[900] : Colors.grey[100],
            child: AdWidget(ad: _nativeAd!),
          )
        : const SizedBox(); // యాడ్ లోడ్ అవ్వకపోతే ఖాళీ స్పేస్ చూపిస్తుంది
  }
}
