import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';

class AdService {
  static AdService? _instance;
  static AdService get instance => _instance ??= AdService._();

  AdService._();

  static const String _bannerAdUnitId =
      'ca-app-pub-1472609237394607/8084106825';
  static const String _interstitialAdUnitId =
      'ca-app-pub-1472609237394607/5863485201';

  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;
  Timer? _intervalTimer;

  // Callback for when interstitial is ready to show
  Function()? onInterstitialReady;

  // ========== BANNER AD ==========
  BannerAd createBannerAd() {
    return BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (kDebugMode) print('✅ Banner ad loaded');
        },
        onAdFailedToLoad: (ad, error) {
          if (kDebugMode) print('❌ Banner ad failed: $error');
          ad.dispose();
        },
      ),
    );
  }

  // ========== INTERSTITIAL AD ==========
  void loadInterstitialAd() {
    if (_isInterstitialLoading) return;
    _isInterstitialLoading = true;

    if (kDebugMode) print('📢 Loading interstitial ad...');

    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          if (kDebugMode) print('✅ Interstitial ad loaded');

          // Notify that interstitial is ready
          onInterstitialReady?.call();

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              if (kDebugMode) print('👋 Interstitial ad dismissed');
              // Load next ad for next time
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              if (kDebugMode) print('❌ Failed to show interstitial: $error');
              ad.dispose();
              _interstitialAd = null;
              _isInterstitialLoading = false;
              // Load next ad
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          if (kDebugMode) print('❌ Interstitial ad failed to load: $error');
          _isInterstitialLoading = false;
          _interstitialAd = null;
        },
      ),
    );
  }

  void showInterstitialAd() {
    if (_interstitialAd != null) {
      if (kDebugMode) print('📺 Showing interstitial ad');
      _interstitialAd!.show();
    } else {
      if (kDebugMode) print('⚠️ Interstitial ad not ready, loading now');
      loadInterstitialAd();
    }
  }

  // Show interstitial if ready, otherwise just execute callback
  void showInterstitialIfReady(VoidCallback onComplete) {
    if (_interstitialAd != null) {
      // Store callback to execute after ad closes
      final originalCallback = _interstitialAd?.fullScreenContentCallback;
      _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          originalCallback?.onAdDismissedFullScreenContent?.call(ad);
          onComplete();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          originalCallback?.onAdFailedToShowFullScreenContent?.call(ad, error);
          onComplete();
        },
      );
      _interstitialAd!.show();
    } else {
      // No ad ready, just execute callback
      onComplete();
    }
  }

  // ========== INTERVAL TIMER (every 5 minutes) ==========
  void startIntervalTimer() {
    _intervalTimer?.cancel();
    _intervalTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (kDebugMode) print('⏰ 5 minutes passed, showing interstitial ad');
      showInterstitialAd();
    });
  }

  void stopIntervalTimer() {
    _intervalTimer?.cancel();
    _intervalTimer = null;
  }

  // Preload interstitial for next time
  void preloadInterstitial() {
    if (_interstitialAd == null && !_isInterstitialLoading) {
      loadInterstitialAd();
    }
  }

  void dispose() {
    _intervalTimer?.cancel();
    _interstitialAd?.dispose();
  }
}
