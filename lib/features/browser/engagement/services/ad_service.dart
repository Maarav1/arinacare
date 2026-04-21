// lib/features/browser/engagement/services/ad_service.dart
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive/hive.dart';
import 'package:arina_cave/features/browser/domain/models/browser_settings.dart';
import 'package:arina_cave/features/browser/domain/models/engagement_metrics.dart';

class AdService {
  static const String bannerAdUnitId = 'ca-app-pub-1472609237394607/7118264698';
  static const String interstitialAdUnitId = 'ca-app-pub-1472609237394607/3819175757';
  
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  int _pageViewCount = 0;
  
 // bool get isInitialized => MobileAds.instance is MobileAds;
  
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    
    // Load initial ads
    _loadBannerAd();
    _loadInterstitialAd();
  }
  
  Future<void> _loadBannerAd() async {
    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: bannerAdUnitId,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _recordAdImpression();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
        onAdClicked: (ad) {
          _recordAdClick();
        },
      ),
      request: const AdRequest(),
    );
    
    await _bannerAd!.load();
  }
  
  Future<void> _loadInterstitialAd() async {
    await InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              _recordAdImpression();
            },
            onAdClicked: (ad) {
              _recordAdClick();
            },
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitialAd(); // Pre-load next
            },
          );
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
        },
      ),
    );
  }
  
  Widget buildBannerAd({double height = 50}) {
    final settingsBox = Hive.box<BrowserSettings>('browser_settings');
    final settings = settingsBox.get('main');
    
    // Respect user preference
    if (settings?.showAds != true) {
      return SizedBox(height: height);
    }
    
    if (_bannerAd != null) {
      return Container(
        height: height,
        alignment: Alignment.center,
        child: AdWidget(ad: _bannerAd!),
      );
    }
    
    return Container(
      height: height,
      color: Colors.grey[900],
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
  
  Future<bool> showInterstitialAd() async {
    final settingsBox = Hive.box<BrowserSettings>('browser_settings');
    final settings = settingsBox.get('main');
    
    // Respect user preference
    if (settings?.showAds != true) {
      return false;
    }
    
    // Show every 3 page views (configurable)
    _pageViewCount++;
    if (_pageViewCount >= 3 && _interstitialAd != null) {
      _pageViewCount = 0;
      await _interstitialAd!.show();
      return true;
    }
    
    return false;
  }
  
  void _recordAdImpression() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final metricsBox = await Hive.openBox<EngagementMetrics>('engagement_metrics');
    
    var metrics = metricsBox.get(today);
    metrics ??= EngagementMetrics(date: today);
    
    metrics.incrementAdImpressions();
    await metricsBox.put(today, metrics);
  }
  
  void _recordAdClick() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final metricsBox = await Hive.openBox<EngagementMetrics>('engagement_metrics');
    
    var metrics = metricsBox.get(today);
    metrics ??= EngagementMetrics(date: today);
    
    metrics.incrementAdClicks();
    await metricsBox.put(today, metrics);
  }
  
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
  }
}