// lib/helpers/ad_helper.dart

import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  static InterstitialAd? _interstitialAd;

  // 🔴 REAL ID (మీ రియల్ యాడ్స్ వస్తాయి)
  static const String interstitialAdId =
      'ca-app-pub-7426724746409466/7805639338';

  static void loadInterstitial() {
    InterstitialAd.load(
      adUnitId: interstitialAdId,
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

  static void showInterstitial() {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
      loadInterstitial(); // యాడ్ చూశాక వెంటనే నెక్స్ట్ యాడ్ ని బ్యాక్ గ్రౌండ్ లో లోడ్ చేస్తుంది
    } else {
      loadInterstitial();
    }
  }
}
