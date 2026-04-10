import 'package:flutter/foundation.dart'; // 🌟 THE FIX: kDebugMode కోసం ఇది కచ్చితంగా ఉండాలి
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  static InterstitialAd? _interstitialAd;

  // యాడ్ లోడ్ చేయడం
  static void loadInterstitial() {
    InterstitialAd.load(
      // 🌟 THE FIX: టెస్టింగ్ అప్పుడు టెస్ట్ యాడ్, ప్రొడక్షన్ లో రియల్ యాడ్
      adUnitId: kDebugMode
          ? 'ca-app-pub-3940256099942544/1033173712' // ఇది టెస్ట్ ఐడీ
          : 'ca-app-pub-7426724746409466/7805639338', // 👈 ఇది మీ రియల్ Interstitial ID
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _interstitialAd = null;
        },
      ),
    );
  }

  // యాడ్ చూపించడం
  static void showInterstitial() {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
      loadInterstitial(); // మళ్ళీ లోడ్ చేసి ఉంచుతాం
    } else {
      loadInterstitial();
    }
  }
}
