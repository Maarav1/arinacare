import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';

class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<RadioStation> _stations = [];
  bool _isLoading = true;
  bool _isPlaying = false;
  bool _isBuffering = false;
  RadioStation? _currentStation;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  Duration? _currentPosition;
  Duration? _totalDuration;
  
  // Ad variables
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isBannerAdLoaded = false;
  Timer? _interstitialTimer;
  
  // Ad unit IDs
  static const String _bannerAdUnitId = 'ca-app-pub-1472609237394607/7118264698';
  static const String _interstitialAdUnitId = 'ca-app-pub-1472609237394607/3819175757';

  @override
  void initState() {
    super.initState();
    _initializeRadio();
    _initializeAds();
    _startInterstitialTimer();
    
    // Show interstitial immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showInterstitialAd();
    });
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _audioPlayer.dispose();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _interstitialTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeRadio() async {
    // Initialize stations
    _stations.addAll([
      RadioStation(
        id: 'bbc_world_service',
        name: 'BBC World Service',
        description: 'International news, analysis and information',
        streamUrl: 'https://stream.live.vc.bbcmedia.co.uk/bbc_world_service',
        logoUrl: 'https://cdn.pixabay.com/photo/2016/06/13/17/30/logo-1454921_1280.png',
        language: 'English',
        category: 'News',
        country: 'UK',
        color: Colors.blue,
      ),
      RadioStation(
        id: 'npr',
        name: 'NPR News',
        description: 'National Public Radio - US',
        streamUrl: 'https://npr-ice.streamguys1.com/live.mp3',
        logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/77/NPR_logo_2021.svg/512px-NPR_logo_2021.svg.png',
        language: 'English',
        category: 'News',
        country: 'USA',
        color: Colors.indigo,
      ),

      RadioStation(
  id: 'rthk_radio_3',
  name: 'NPR China',
  description: 'Hong Kong Public Broadcaster - News & Info',
  // Confirmed working HTTPS stream China 
  streamUrl: 'https://stm.rthk.hk/radio3', 
  logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e3/Radio_Television_Hong_Kong_Logo.svg/1200px-Radio_Television_Hong_Kong_Logo.svg.png',
  language: 'English',
  category: 'News',
  country: 'Hong Kong',
  color: Colors.lightBlue,
),

      RadioStation(
  id: 'dw_english',
  name: 'DW English',
  description: 'Deutsche Welle - German international broadcaster',
  // Official DW English Live Audio/Video Stream (HLS format, highly stable)
  streamUrl: 'https://dwamdstream102.akamaized.net/hls/live/2015525/dwstream102/index.m3u8',
  // High-res official transparent logo
  logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/23/Deutsche_Welle_logo_2012.svg/1024px-Deutsche_Welle_logo_2012.svg.png',
  language: 'English',
  category: 'News',
  country: 'Germany',
  color: Colors.green, 
),
    ]);

    // Configure audio session for background playback
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth |
            AVAudioSessionCategoryOptions.allowBluetoothA2dp |
            AVAudioSessionCategoryOptions.allowAirPlay,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));
    } catch (e) {
      debugPrint('Audio session configuration error: $e');
    }

    // Set first station as current
    _currentStation = _stations.first;
    
    // Listen for player state changes
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((playerState) {
      setState(() {
        _isPlaying = playerState.playing;
        _isBuffering = playerState.processingState == ProcessingState.buffering;
      });
    });

    // Listen for position updates
    _positionSubscription = _audioPlayer.positionStream.listen((position) {
      setState(() {
        _currentPosition = position;
      });
    });

    // Listen for duration updates
    _audioPlayer.durationStream.listen((duration) {
      setState(() {
        _totalDuration = duration;
      });
    });

    // Handle errors
    _audioPlayer.playbackEventStream.listen((event) {}, onError: (e) {
      debugPrint('Audio error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error playing stream. Trying backup...'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                if (_currentStation != null) {
                  _playStation(_currentStation!);
                }
              },
            ),
          ),
        );
      }
    });

    setState(() {
      _isLoading = false;
    });
  }

  void _initializeAds() {
    // Load banner ad
    _loadBannerAd();
    
    // Pre-load interstitial ad
    _loadInterstitialAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          debugPrint('Banner ad loaded successfully');
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint('Banner ad failed to load: $error');
          ad.dispose();
          // Try to reload after delay
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              _loadBannerAd();
            }
          });
        },
      ),
    );
    _bannerAd?.load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              ad.dispose();
              _loadInterstitialAd(); // Pre-load next interstitial
            },
            onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
              ad.dispose();
              _loadInterstitialAd(); // Pre-load next interstitial
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('Interstitial ad failed to load: $error');
          // Try again after 30 seconds
          Future.delayed(const Duration(seconds: 30), () {
            _loadInterstitialAd();
          });
        },
      ),
    );
  }

  void _startInterstitialTimer() {
    // Show interstitial every 5 minutes
    _interstitialTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) {
        _showInterstitialAd();
      }
    });
  }

  void _showInterstitialAd() {
    if (_interstitialAd != null) {
      _interstitialAd?.show();
    } else {
      _loadInterstitialAd();
    }
  }

  Future<void> _playStation(RadioStation station) async {
    try {
      if (_currentStation?.id == station.id && _isPlaying) {
        await _audioPlayer.pause();
        return;
      }
      
      _currentStation = station;
      
      // Show loading
      setState(() {
        _isBuffering = true;
      });
      
      // Stop current playback
      await _audioPlayer.stop();
      
      // Set new source
      await _audioPlayer.setUrl(station.streamUrl);
      
      // Start playback
      await _audioPlayer.play();
      
      setState(() {
        _isBuffering = false;
      });
      
    } catch (e) {
      debugPrint('Error playing station: $e');
      if (mounted) {
        setState(() {
          _isBuffering = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot play ${station.name}. Check internet connection.'),
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
      }
      return;
    }
    
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_audioPlayer.processingState == ProcessingState.idle) {
        await _playStation(_currentStation!);
      } else {
        await _audioPlayer.play();
      }
    }
  }

  Future<void> _stopPlayback() async {
    await _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
      _currentPosition = null;
    });
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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
          if (_currentStation != null)
            _buildNowPlayingSection(),
          
          // Stations List
          Expanded(
            child: _isLoading
                ? _buildLoadingShimmer()
                : RefreshIndicator(
                    onRefresh: () async {
                      // Simple refresh
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
          
          // Banner Ad at the bottom
          if (_isBannerAdLoaded && _bannerAd != null)
            Container(
              alignment: Alignment.center,
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }

  Widget _buildNowPlayingSection() {
    final station = _currentStation!;
    final _ = _isPlaying && _currentStation?.id == station.id;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            station.color.withValues(),
            station.color.withValues(),
          ],
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
                        color: station.color.withValues(),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: station.color.withValues()),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: station.logoUrl.isNotEmpty
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
                          value: _totalDuration != null && _totalDuration!.inSeconds > 0
                              ? (_currentPosition?.inSeconds ?? 0) / _totalDuration!.inSeconds
                              : 0,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(station.color),
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
                          color: station.color.withValues(),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: _isBuffering
                        ? const Center(
                            child: SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
          
          // Divider
          Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
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
      color: isCurrent ? station.color.withValues() : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCurrent ? station.color.withValues() : Colors.transparent,
          width: isCurrent ? 2 : 0,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: station.color.withValues(),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: station.color.withValues()),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: station.logoUrl.isNotEmpty
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
                    child: Icon(
                      Icons.radio,
                      color: station.color,
                      size: 24,
                    ),
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
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: station.color.withValues(),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.language,
                        size: 12,
                        color: station.color,
                      ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
            child: isCurrentPlaying
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
                Container(
                  width: 100,
                  height: 20,
                  color: Colors.grey.shade300,
                ),
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

class RadioStation {
  final String id;
  final String name;
  final String description;
  final String streamUrl;
  final String logoUrl;
  final String language;
  final String category;
  final String country;
  final Color color;

  RadioStation({
    required this.id,
    required this.name,
    required this.description,
    required this.streamUrl,
    required this.logoUrl,
    required this.language,
    required this.category,
    required this.country,
    required this.color,
  });
}
