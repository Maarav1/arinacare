import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';
import 'audio_service.dart'; // Your AudioService singleton

class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  final AudioService _audioService = AudioService();

  // Ad variables (same as Gemini)
  late BannerAd _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isBannerAdLoaded = false;
  bool _isInterstitialAdLoaded = false;
  Timer? _interstitialTimer;
  int _stationPlayCount = 0;

  // UI state from audio service
  bool _isPlaying = false;
  bool _isBuffering = false;
  RadioStation? _currentStation;
  Duration? _currentPosition;
  Duration? _totalDuration;

  final List<RadioStation> _stations = [];
  bool _isLoading = true;

  // Stream subscriptions
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _initializeRadio();
    _initializeAds();
    _listenToAudioService();
  }

  @override
  void dispose() {
    // Cancel stream subscriptions
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _bannerAd.dispose();
    _interstitialTimer?.cancel();
    if (_interstitialAd != null) {
      _interstitialAd!.dispose();
    }
    super.dispose();
  }

  void _listenToAudioService() {
    _subscriptions.add(
      _audioService.playingStateStream.listen((playing) {
        if (mounted) setState(() => _isPlaying = playing);
      }),
    );

    _subscriptions.add(
      _audioService.bufferingStateStream.listen((buffering) {
        if (mounted) setState(() => _isBuffering = buffering);
      }),
    );

    _subscriptions.add(
      _audioService.positionStream.listen((position) {
        if (mounted) setState(() => _currentPosition = position);
      }),
    );

    _subscriptions.add(
      _audioService.durationStream.listen((duration) {
        if (mounted) setState(() => _totalDuration = duration);
      }),
    );

    _subscriptions.add(
      _audioService.stationStream.listen((station) {
        if (mounted) setState(() => _currentStation = station);
      }),
    );
  }

  // ============ ADS IMPLEMENTATION (Same as Gemini) ============

  void _initializeAds() {
    MobileAds.instance.initialize();
    _loadBannerAd();
    _loadInterstitialAd();
    _startInterstitialTimer();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: 'ca-app-pub-1472609237394607/7118264698',
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          setState(() {
            _isBannerAdLoaded = false;
          });
        },
      ),
      request: const AdRequest(),
    );
    _bannerAd.load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-1472609237394607/5863485201',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoaded = true;
          _setupInterstitialAdListeners();
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isInterstitialAdLoaded = false;
        },
      ),
    );
  }

  void _setupInterstitialAdListeners() {
    _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialAdLoaded = false;
        _loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialAdLoaded = false;
        _loadInterstitialAd();
      },
    );
  }

  void _startInterstitialTimer() {
    _interstitialTimer?.cancel();
    _interstitialTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isInterstitialAdLoaded && _interstitialAd != null) {
        _showInterstitialAd();
      }
    });
  }

  void _showInterstitialAd() {
    if (_interstitialAd != null && _isInterstitialAdLoaded) {
      _interstitialAd!.show();
      _interstitialTimer?.cancel();
      _startInterstitialTimer();
    }
  }

  void _showInterstitialIfNeeded() {
    _stationPlayCount++;
    if (_stationPlayCount % 5 == 0) {
      _showInterstitialAd();
    }
  }

  Widget _buildBannerAd() {
    if (!_isBannerAdLoaded) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: AdWidget(ad: _bannerAd),
    );
  }

  // ============ RADIO IMPLEMENTATION ============

  Future<void> _initializeRadio() async {
    // Initialize audio service first
    await _audioService.initialize();

    // Initialize stations with optimized streams
    _stations.addAll([
      
      RadioStation(
        id: 'npr',
        name: 'NPR News',
        description: 'National Public Radio - US',
        streamUrl: 'https://npr-ice.streamguys1.com/live.mp3',
        logoUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/7/77/NPR_logo_2021.svg/512px-NPR_logo_2021.svg.png',
        language: 'English',
        category: 'News',
        country: 'USA',
        color: Colors.indigo,
        bitrate: '64 kbps',
      ),
      RadioStation(
        id: 'bbc_world_service',
        name: 'BBC World Service',
        description: 'International news, analysis and information',
        streamUrl: 'https://stream.live.vc.bbcmedia.co.uk/bbc_world_service',
        logoUrl:
            'https://cdn.pixabay.com/photo/2016/06/13/17/30/logo-1454921_1280.png',
        language: 'English',
        category: 'News',
        country: 'UK',
        color: Colors.blue,
        bitrate: '48 kbps',
      ),
      RadioStation(
        id: 'rthk_radio_3',
        name: 'RTHK Radio 3',
        description: 'Hong Kong Public Broadcaster - News & Info',
        streamUrl: 'https://stm.rthk.hk/radio3',
        logoUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e3/Radio_Television_Hong_Kong_Logo.svg/1200px-Radio_Television_Hong_Kong_Logo.svg.png',
        language: 'English',
        category: 'News',
        country: 'Hong Kong',
        color: Colors.lightBlue,
        bitrate: '48 kbps',
      ),

      RadioStation(
        id: 'dw_english',
        name: 'DW English',
        description: 'Deutsche Welle - German international broadcaster',
        streamUrl:
            'https://dwamdstream102.akamaized.net/hls/live/2015525/dwstream102/index.m3u8',
        logoUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/2/23/Deutsche_Welle_logo_2012.svg/1024px-Deutsche_Welle_logo_2012.svg.png',
        language: 'English',
        category: 'News',
        country: 'Germany',
        color: Colors.green,
        bitrate: '640 kbps',
      ),
    ]);

    // Set first station as current if nothing is playing
    if (_audioService.currentStation == null) {
      _currentStation = _stations.first;
    } else {
      _currentStation = _audioService.currentStation;
      _isPlaying = _audioService.isPlaying;
      _isBuffering = _audioService.isBuffering;
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _playStation(RadioStation station) async {
    try {
      _showInterstitialIfNeeded();
      await _audioService.playStation(station);
      // State will update via streams
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot play ${station.name}. Check internet connection.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _togglePlayback() async {
    if (_currentStation == null) {
      if (_stations.isNotEmpty) {
        await _playStation(_stations.first);
        _showInterstitialIfNeeded();
      }
      return;
    }
    await _audioService.togglePlayback();
  }

  Future<void> _stopPlayback() async {
    await _audioService.stop();
  }

  String _formatDuration(Duration? duration) {
    return _audioService.formatDuration(duration);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ArinaCave Radio',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_currentStation != null && _isPlaying)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopPlayback,
              tooltip: 'Stop',
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showRadioInfo,
            tooltip: 'Info',
          ),
        ],
      ),
      body: Column(
        children: [
          // Now Playing Section
          if (_currentStation != null) _buildNowPlayingSection(),

          // Stations List
          Expanded(
            child:
                _isLoading
                    ? _buildLoadingShimmer()
                    : RefreshIndicator(
                      onRefresh: () async {
                        setState(() {});
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _stations.length,
                        itemBuilder: (context, index) {
                          return _buildStationCard(_stations[index]);
                        },
                      ),
                    ),
          ),

          // Banner Ad (same as Gemini)
          _buildBannerAd(),
        ],
      ),
    );
  }

  Widget _buildNowPlayingSection() {
    final station = _currentStation!;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [station.color.withAlpha(50), station.color.withAlpha(20)],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Station logo and info
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: station.color.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: station.color, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child:
                            station.logoUrl.isNotEmpty
                                ? Image.network(
                                  station.logoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.radio,
                                      color: station.color,
                                      size: 32,
                                    );
                                  },
                                )
                                : Icon(
                                  Icons.radio,
                                  color: station.color,
                                  size: 32,
                                ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NOW PLAYING',
                            style: TextStyle(
                              fontSize: 12,
                              color: station.color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            station.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            station.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Bitrate: ${station.bitrate}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Playback controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Position
                    Text(
                      _formatDuration(_currentPosition),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Progress bar
                    Expanded(
                      child: SizedBox(
                        height: 4,
                        child: LinearProgressIndicator(
                          value:
                              _totalDuration != null &&
                                      _totalDuration!.inSeconds > 0
                                  ? (_currentPosition?.inSeconds ?? 0) /
                                      _totalDuration!.inSeconds
                                  : 0,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            station.color,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Duration
                    Text(
                      _totalDuration != null && _totalDuration!.inSeconds > 0
                          ? _formatDuration(_totalDuration)
                          : 'LIVE',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Play/Pause button
                GestureDetector(
                  onTap: _togglePlayback,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: station.color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: station.color.withAlpha(100),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child:
                        _isBuffering
                            ? const Center(
                              child: SizedBox(
                                width: 30,
                                height: 30,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                            )
                            : Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 36,
                            ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  Widget _buildStationCard(RadioStation station) {
    final isCurrent = _currentStation?.id == station.id;
    final isCurrentPlaying = isCurrent && _isPlaying;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isCurrent ? 3 : 1,
      color: isCurrent ? station.color.withAlpha(30) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCurrent ? station.color : Colors.transparent,
          width: isCurrent ? 2 : 0,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: station.color.withAlpha(30),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: station.color, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child:
                station.logoUrl.isNotEmpty
                    ? Image.network(
                      station.logoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            Icons.radio,
                            color: station.color,
                            size: 24,
                          ),
                        );
                      },
                    )
                    : Center(
                      child: Icon(Icons.radio, color: station.color, size: 24),
                    ),
          ),
        ),
        title: Text(
          station.name,
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
            color: isCurrent ? station.color : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              station.description,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: station.color.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.language, size: 12, color: station.color),
                      const SizedBox(width: 4),
                      Text(
                        station.language,
                        style: TextStyle(
                          fontSize: 10,
                          color: station.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    station.country,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    station.bitrate,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCurrent ? station.color : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Center(
            child:
                isCurrentPlaying
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : Icon(
                      isCurrent && _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: isCurrent ? Colors.white : Colors.grey.shade700,
                    ),
          ),
        ),
        onTap: () => _playStation(station),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            title: Container(
              width: 150,
              height: 16,
              color: Colors.grey.shade300,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 12,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 8),
                Container(width: 100, height: 20, color: Colors.grey.shade300),
              ],
            ),
            trailing: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRadioInfo() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ArinaCave Radio',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Stream live radio from international news broadcasters. '
                'Audio continues playing in background when you navigate away.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              const Text(
                'Features:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildInfoItem(Icons.play_arrow, 'Tap any station to play'),
              _buildInfoItem(Icons.volume_up, 'Audio plays in background'),
              _buildInfoItem(Icons.language, 'International news in English'),
              _buildInfoItem(
                Icons.data_usage,
                'Optimized low-bitrate streams to save data',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
