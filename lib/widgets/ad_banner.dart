import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    final ad = BannerAd(
      adUnitId:
          'ca-app-pub-1472609237394607/8084106825', // Your banner ad unit ID
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loadedAd) {
          if (kDebugMode) print('✅ Banner ad loaded');
          if (mounted) {
            setState(() {
              _bannerAd = loadedAd as BannerAd;
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (loadedAd, error) {
          if (kDebugMode) print('❌ Banner ad failed to load: $error');
          loadedAd.dispose();
          if (mounted) {
            setState(() {
              _bannerAd = null;
              _isAdLoaded = false;
            });
          }
          // Optional: Retry after delay
          Future.delayed(const Duration(seconds: 30), () {
            if (mounted && _bannerAd == null) {
              _loadBannerAd();
            }
          });
        },
      ),
    );

    ad.load();

    setState(() {
      _bannerAd = ad;
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Returns NOTHING until ad is loaded - NO wasted space!
    if (_bannerAd == null || !_isAdLoaded) {
      return const SizedBox.shrink(); // Takes 0 space
    }

    return Container(
      height: 50,
      alignment: Alignment.center,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
