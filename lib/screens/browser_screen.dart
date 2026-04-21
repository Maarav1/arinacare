// lib/screens/browser_screen.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

// Ad unit IDs
const String _bannerAdUnitId = 'ca-app-pub-1472609237394607/7118264698';
const String _interstitialAdUnitId = 'ca-app-pub-1472609237394607/3819175757';

class BrowserScreen extends StatefulWidget {
  final String? initialUrl;
  
  const BrowserScreen({
    super.key,
    this.initialUrl,
  });
  
  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> 
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  // WebView controller
  WebViewController? _controller;
  
  // UI state
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  bool _isLoading = false;
  double _progress = 0.0;
  String _currentUrl = '';
  String _currentTitle = '';
  bool _showHomepage = true;
  bool _showSearchSuggestions = true;
  final List<String> _history = [];
  int _navigationCount = 0;
  
  // AdMob
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isBannerAdLoaded = false;
  bool _isInterstitialAdLoaded = false;
  
  // User agent for SupaCave browser
  static const String _userAgent = 'Mozilla/5.0 (Linux; Android 10; SupaCave Browser) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
  
  // Search engines
  static const Map<String, Map<String, dynamic>> _searchEngines = {
    'google': {
      'name': 'Google',
      'url': 'https://www.google.com/search?q=',
      'icon': Icons.search,
      'color': Colors.blue,
    },
    'bing': {
      'name': 'Bing',
      'url': 'https://www.bing.com/search?q=',
      'icon': Icons.explore,
      'color': Colors.green,
    },
    'duckduckgo': {
      'name': 'DuckDuckGo',
      'url': 'https://duckduckgo.com/?q=',
      'icon': Icons.security,
      'color': Colors.orange,
    },
    'youtube': {
      'name': 'YouTube',
      'url': 'https://www.youtube.com/results?search_query=',
      'icon': Icons.play_circle_filled,
      'color': Colors.red,
    },
    'wikipedia': {
      'name': 'Wikipedia',
      'url': 'https://en.wikipedia.org/w/index.php?search=',
      'icon': Icons.menu_book,
      'color': Colors.grey,
    },
  };
  
  // Quick apps for homepage
  static const List<Map<String, dynamic>> _quickApps = [
    {
      'name': 'Google',
      'url': 'https://www.google.com',
      'icon': Icons.search,
      'color': Colors.blue,
      'description': 'Search the web',
    },
    {
      'name': 'YouTube',
      'url': 'https://www.youtube.com',
      'icon': Icons.play_circle_filled,
      'color': Colors.red,
      'description': 'Watch videos',
    },
     {
      'name': 'DeepSeek',
      'url': 'https://chat.deepseek.com',
      'icon': Icons.smart_toy, // or Icons.chat, Icons.psychology
      'color': Colors.deepPurple, // Purple color for AI
      'description': 'AI Assistant',
    },
   
    {
      'name': 'TikTok',
      'url': 'https://www.tiktok.com',
      'icon': Icons.music_note, // or Icons.video_library
      'color': Colors.black, // TikTok's brand color
      'description': 'Short videos',
    },
    {
      'name': 'GitHub',
      'url': 'https://www.github.com',
      'icon': Icons.code,
      'color': Colors.black,
      'description': 'Code repository',
    },
    {
      'name': 'ChatGPT',
      'url': 'https://chat.openai.com',
      'icon': Icons.smart_toy,
      'color': Colors.green,
      'description': 'AI Assistant',
    },
    {
      'name': 'Twitter',
      'url': 'https://twitter.com',
      'icon': Icons.chat,
      'color': Colors.blue,
      'description': 'Social media',
    },
    {
      'name': 'Reddit',
      'url': 'https://www.reddit.com',
      'icon': Icons.forum,
      'color': Colors.orange,
      'description': 'Online community',
    },
    {
      'name': 'Wikipedia',
      'url': 'https://www.wikipedia.org',
      'icon': Icons.menu_book,
      'color': Colors.grey,
      'description': 'Free encyclopedia',
    },
    {
      'name': 'Amazon',
      'url': 'https://www.amazon.com',
      'icon': Icons.shopping_cart,
      'color': Colors.orange,
      'description': 'Online shopping',
    },
    {
      'name': 'Instagram',
      'url': 'https://www.instagram.com',
      'icon': Icons.camera_alt,
      'color': Colors.pink,
      'description': 'Photo sharing',
    },
    {
      'name': 'Facebook',
      'url': 'https://www.facebook.com',
      'icon': Icons.people,
      'color': Colors.blue,
      'description': 'Social network',
    },
    {
      'name': 'Netflix',
      'url': 'https://www.netflix.com',
      'icon': Icons.movie,
      'color': Colors.red,
      'description': 'Stream movies',
    },
    {
      'name': 'Spotify',
      'url': 'https://open.spotify.com',
      'icon': Icons.music_note,
      'color': Colors.green,
      'description': 'Music streaming',
    },
  ];
  
  // Settings
  bool _showAds = true;
  String _defaultSearchEngine = 'google';
  bool _darkMode = true;
  bool _desktopMode = false;
  bool _javascriptEnabled = true;
  bool _enableAdBlock = false;
  int _adFrequency = 5;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeWebView();
    _initializeAds();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeShowInterstitialAd();
    }
  }

  Future<void> _initializeWebView() async {
    _controller = WebViewController();
    
    // Configure the controller
    _controller!
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setUserAgent(_desktopMode 
          ? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
          : _userAgent)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (progress) {
            // Check if widget is still mounted before updating state
            if (mounted) {
              setState(() {
                _progress = progress / 100;
                _isLoading = progress < 100;
              });
            }
          },
        onPageStarted: (url) {
            // Check if widget is still mounted before updating state
            if (mounted) {
              setState(() {
                _currentUrl = url;
                _isLoading = true;
                _showHomepage = false;
                _urlController.text = url;
              });
            }
            _navigationCount++;
            _maybeShowInterstitialAd();

            // Add to history
            if (_history.isEmpty || _history.last != url) {
              _history.add(url);
            }
          },
        onPageFinished: (url) async {
            final title = await _controller!.getTitle();
            // Check if widget is still mounted before updating state
            if (mounted) {
              setState(() {
                _currentUrl = url;
                _isLoading = false;
                _currentTitle = title ?? 'SupaCave Browser';
                _urlController.text = url;
              });
            }
          },
        onUrlChange: (change) {
          setState(() {
            _currentUrl = change.url ?? '';
            _urlController.text = _currentUrl;
          });
        },
        onNavigationRequest: (request) {
          // Handle external URLs
          if (request.url.startsWith('mailto:') || 
              request.url.startsWith('tel:') ||
              request.url.startsWith('sms:')) {
            _launchExternalUrl(request.url);
            return NavigationDecision.prevent;
          }
          
          // Handle downloads
          if (request.url.contains('/download/') ||
              request.url.endsWith('.apk') ||
              request.url.endsWith('.zip') ||
              request.url.endsWith('.pdf') ||
              request.url.endsWith('.doc') ||
              request.url.endsWith('.docx')) {
            _showDownloadDialog(request.url);
            return NavigationDecision.prevent;
          }
          
          return NavigationDecision.navigate;
        },
      ))
      ..addJavaScriptChannel('SupaCave', 
          onMessageReceived: (JavaScriptMessage message) {
        if (kDebugMode) {
          print('JavaScript: ${message.message}');
        }
      });
    
    // Load initial URL if provided
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      await _loadUrl(widget.initialUrl!);
    }
  }

  void _initializeAds() {
    if (_showAds) {
      _loadBannerAd();
      _loadInterstitialAd();
    }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerAdLoaded = true;
          });
          if (kDebugMode) {
            print('Banner ad loaded');
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (kDebugMode) {
            print('Banner ad failed to load: $error');
          }
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
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoaded = true;
          if (kDebugMode) {
            print('Interstitial ad loaded');
          }
        },
        onAdFailedToLoad: (error) {
          if (kDebugMode) {
            print('Interstitial ad failed to load: $error');
          }
        },
      ),
    );
  }

  void _maybeShowInterstitialAd() {
    if (_showAds && 
        _isInterstitialAdLoaded && 
        _navigationCount % _adFrequency == 0 &&
        _navigationCount > 0) {
      _interstitialAd?.show();
      _loadInterstitialAd(); // Load next one
    }
  }

  Future<void> _loadUrl(String input) async {
    if (input.isEmpty) return;

    String finalUrl = input.trim();

    // Check if it's a search query
    if (!finalUrl.contains('.') || finalUrl.contains(' ')) {
      final engine = _searchEngines[_defaultSearchEngine]!;
      finalUrl = '${engine['url']}${Uri.encodeComponent(finalUrl)}';
    }
    // Add https:// if missing
    else if (!finalUrl.startsWith('http://') &&
        !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }

    try {
      await _controller!.loadRequest(Uri.parse(finalUrl));
      _showSearchSuggestions = false;

      // Vibrate on navigation
      HapticFeedback.lightImpact();
    } catch (e) {
      // Check if widget is still mounted before showing snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading URL: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchExternalUrl(String url) async {
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        // Check if widget is still mounted before showing snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot launch: $url'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Check if widget is still mounted before showing snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching URL: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDownloadDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _darkMode ? Colors.grey[900] : Colors.white,
        title: Text(
          'Download File',
          style: TextStyle(color: _darkMode ? Colors.white : Colors.black),
        ),
        content: Text(
          'Download file from $url?',
          style: TextStyle(color: _darkMode ? Colors.white : Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: _darkMode ? Colors.white : Colors.black),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _launchExternalUrl(url);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Downloading: $url'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text(
              'Download',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomepage() {
    return Container(
      color: _darkMode ? Colors.black : Colors.grey[100],
      child: Column(
        children: [
          // Welcome header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _darkMode
                    ? [Colors.blue[900]!, Colors.purple[900]!]
                    : [Colors.blue[100]!, Colors.purple[100]!],
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.public,
                  size: 60,
                  color: _darkMode ? Colors.white : Colors.blue[900],
                ),
                const SizedBox(height: 16),
                Text(
                  'SupaCave Browser',
                  style: TextStyle(
                    color: _darkMode ? Colors.white : Colors.blue[900],
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fast, Secure, and Private',
                  style: TextStyle(
                    color: _darkMode ? Colors.white70 : Colors.blue[700],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Quick search bar
Container(
  padding: const EdgeInsets.all(20),
  color: _darkMode ? Colors.grey[900] : Colors.white,
  child: Row(
    children: [
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: _darkMode ? Colors.grey[800] : Colors.grey[200],
            borderRadius: BorderRadius.circular(25),
          ),
          child: TextField(
            controller: _urlController,
            focusNode: _urlFocusNode,
            style: TextStyle(
              color: _darkMode ? Colors.white : Colors.black,
              fontSize: 16, // Increased font size
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Search or enter URL',
              hintStyle: TextStyle(
                color: _darkMode ? Colors.grey[400] : Colors.grey[600],
                fontSize: 16, // Increased hint font size
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20, 
                vertical: 18, // Increased vertical padding
              ),
              prefixIcon: Icon(
                Icons.search,
                color: _darkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            onSubmitted: _loadUrl,
            onTap: () {
              setState(() {
                _showSearchSuggestions = true;
              });
            },
          ),
        ),
      ),
      const SizedBox(width: 10),
      FloatingActionButton(
        backgroundColor: Colors.blue,
        onPressed: _showMainMenu,
        child: const Icon(Icons.menu, color: Colors.white),
      ),
    ],
  ),
),
          
          // Quick apps grid
          Expanded(
            child: Container(
              color: _darkMode ? Colors.black : Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Apps',
                      style: TextStyle(
                        color: _darkMode ? Colors.white : Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: _quickApps.length,
                        itemBuilder: (context, index) {
                          final app = _quickApps[index];
                          return GestureDetector(
                            onTap: () => _loadUrl(app['url']),
                            onLongPress: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${app['name']}: ${app['description']}'),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: _darkMode ? Colors.grey[900] : Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: app['color'] as Color,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      app['icon'] as IconData,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    app['name'] as String,
                                    style: TextStyle(
                                      color: _darkMode ? Colors.white : Colors.black,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Recent history
          if (_history.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              color: _darkMode ? Colors.grey[900] : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent History',
                        style: TextStyle(
                          color: _darkMode ? Colors.white : Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.clear_all,
                          color: _darkMode ? Colors.white : Colors.black,
                        ),
                        onPressed: () {
                          setState(() {
                            _history.clear();
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _history.take(5).length,
                      itemBuilder: (context, index) {
                        final url = _history.reversed.toList()[index];
                        return GestureDetector(
                          onTap: () => _loadUrl(url),
                          child: Container(
                            width: 200,
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _darkMode ? Colors.grey[800] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history,
                                  color: _darkMode ? Colors.white : Colors.black,
                                  size: 16,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  url.length > 30 ? '${url.substring(0, 30)}...' : url,
                                  style: TextStyle(
                                    color: _darkMode ? Colors.white : Colors.black,
                                    fontSize: 10,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUrlBar() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: _darkMode ? Colors.grey[900]! : Colors.grey[200]!,
      border: Border(bottom: BorderSide(color: _darkMode ? Colors.grey[800]! : Colors.grey[300]!)),
    ),
    child: Row(
      children: [
        // Back button
        StreamBuilder<bool>(
          stream: _controller?.canGoBack().asStream(),
          builder: (context, snapshot) {
            final canGoBack = snapshot.data ?? false;
            return IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: canGoBack 
                    ? (_darkMode ? Colors.white : Colors.black)
                    : (_darkMode ? Colors.grey[600] : Colors.grey[400]),
              ),
              onPressed: canGoBack ? () async {
                await _controller?.goBack();
                HapticFeedback.lightImpact();
              } : null,
              style: IconButton.styleFrom(
                backgroundColor: _darkMode ? Colors.grey[800] : Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(8),
              ),
            );
          },
        ),
        
        // Forward button
        StreamBuilder<bool>(
          stream: _controller?.canGoForward().asStream(),
          builder: (context, snapshot) {
            final canGoForward = snapshot.data ?? false;
            return IconButton(
              icon: Icon(
                Icons.arrow_forward,
                color: canGoForward 
                    ? (_darkMode ? Colors.white : Colors.black)
                    : (_darkMode ? Colors.grey[600] : Colors.grey[400]),
                ),
              onPressed: canGoForward ? () async {
                await _controller?.goForward();
                HapticFeedback.lightImpact();
              } : null,
              style: IconButton.styleFrom(
                backgroundColor: _darkMode ? Colors.grey[800] : Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(8),
              ),
            );
          },
        ),
        
        // URL bar - EXPANDED
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _darkMode ? Colors.black : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Security icon (only shown for HTTPS)
                if (_currentUrl.startsWith('https://'))
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Icon(
                      Icons.lock,
                      size: 16,
                      color: Colors.green,
                    ),
                  ),
                
                // URL text field - TAKES MOST SPACE
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    focusNode: _urlFocusNode,
                    style: TextStyle(
                      color: _darkMode ? Colors.white : Colors.black,
                      fontSize: 16, // Increased font size
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Search or enter URL',
                      hintStyle: TextStyle(
                        color: _darkMode ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 16, // Increased hint font size
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, 
                        vertical: 16, // Increased vertical padding
                      ),
                      isDense: false,
                    ),
                    maxLines: 1,
                    textInputAction: TextInputAction.go,
                    onSubmitted: _loadUrl,
                    onTap: () {
                      setState(() {
                        _showSearchSuggestions = true;
                      });
                    },
                  ),
                ),
                
                // Menu button (moved inside URL bar)
                IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    size: 20,
                    color: _darkMode ? Colors.white : Colors.black,
                  ),
                  onPressed: _showMainMenu,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildSearchSuggestions() {
    if (!_showSearchSuggestions) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _darkMode ? Colors.grey[800]! : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search engine selection
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _darkMode ? Colors.grey[700]! : Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Search with ${_searchEngines[_defaultSearchEngine]!['name']}',
                    style: TextStyle(
                      color: _darkMode ? Colors.white : Colors.black,
                      fontSize: 12,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.arrow_drop_down, color: _darkMode ? Colors.white : Colors.black),
                  onSelected: (value) {
                    setState(() {
                      _defaultSearchEngine = value;
                    });
                  },
                  itemBuilder: (context) {
                    return _searchEngines.entries.map((entry) {
                      return PopupMenuItem(
                        value: entry.key,
                        child: Row(
                          children: [
                            Icon(entry.value['icon'] as IconData, 
                                color: entry.value['color'] as Color, size: 20),
                            const SizedBox(width: 8),
                            Text(entry.value['name'] as String),
                          ],
                        ),
                      );
                    }).toList();
                  },
                ),
              ],
            ),
          ),
          
          // Quick suggestions
          ..._quickApps.take(8).map((app) {
            return ListTile(
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: app['color'] as Color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  app['icon'] as IconData,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              title: Text(
                app['name'] as String,
                style: TextStyle(
                  color: _darkMode ? Colors.white : Colors.black,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                app['description'] as String,
                style: TextStyle(
                  color: _darkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 11,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward,
                size: 16,
                color: _darkMode ? Colors.grey[400] : Colors.grey[600],
              ),
              onTap: () {
                _loadUrl(app['url'] as String);
                setState(() {
                  _showSearchSuggestions = false;
                });
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBannerAd() {
    if (!_showAds || !_isBannerAdLoaded || _bannerAd == null) {
      return Container(
        height: 60,
        color: _darkMode ? Colors.black : Colors.grey[100],
        child: Center(
          child: Text(
            'SupaCave Browser',
            style: TextStyle(
              color: _darkMode ? Colors.white54 : Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
    
    return Container(
      height: _bannerAd!.size.height.toDouble(),
      color: Colors.transparent,
      alignment: Alignment.center,
      child: AdWidget(ad: _bannerAd!),
    );
  }

  void _showMainMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _darkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: _darkMode ? Colors.grey[800]! : Colors.grey[200]!)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.public,
                        color: _darkMode ? Colors.white : Colors.black,
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SupaCave Browser',
                              style: TextStyle(
                                color: _darkMode ? Colors.white : Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _currentTitle,
                              style: TextStyle(
                                color: _darkMode ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Quick actions
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    children: [
                      _buildMenuButton(
                        icon: Icons.bookmark,
                        label: 'Bookmarks',
                        onTap: () {
                          Navigator.pop(context);
                          _showBookmarks();
                        },
                      ),
                      _buildMenuButton(
                        icon: Icons.history,
                        label: 'History',
                        onTap: () {
                          Navigator.pop(context);
                          _showHistory();
                        },
                      ),
                      _buildMenuButton(
                        icon: Icons.download,
                        label: 'Downloads',
                        onTap: () {
                          Navigator.pop(context);
                          _showDownloads();
                        },
                      ),
                      _buildMenuButton(
                        icon: Icons.share,
                        label: 'Share',
                        onTap: () {
                          Navigator.pop(context);
                          _sharePage();
                        },
                      ),
                      _buildMenuButton(
                        icon: Icons.print,
                        label: 'Print',
                        onTap: () {
                          Navigator.pop(context);
                          _printPage();
                        },
                      ),
                      _buildMenuButton(
                        icon: Icons.qr_code_scanner,
                        label: 'QR Scan',
                        onTap: () {
                          Navigator.pop(context);
                          _scanQRCode();
                        },
                      ),
                      _buildMenuButton(
                        icon: Icons.translate,
                        label: 'Translate',
                        onTap: () {
                          Navigator.pop(context);
                          _translatePage();
                        },
                      ),
                      _buildMenuButton(
                        icon: Icons.nightlight,
                        label: 'Dark Mode',
                        onTap: () {
                          setState(() {
                            _darkMode = !_darkMode;
                          });
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
                
                // Settings
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.settings,
                          color: _darkMode ? Colors.white : Colors.black,
                        ),
                        title: Text(
                          'Settings',
                          style: TextStyle(
                            color: _darkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: _darkMode ? Colors.white : Colors.black,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _showSettings();
                        },
                      ),
                      
                      SwitchListTile(
                        title: Text(
                          'Desktop Mode',
                          style: TextStyle(
                            color: _darkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        value: _desktopMode,
                        onChanged: (value) {
                          setState(() {
                            _desktopMode = value;
                            _controller?.setUserAgent(value
                                ? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
                                : _userAgent);
                            if (value) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Desktop mode enabled'),
                                ),
                              );
                            }
                          });
                        },
                        activeColor: Colors.blue,
                      ),
                      
                      SwitchListTile(
                        title: Text(
                          'Show Ads',
                          style: TextStyle(
                            color: _darkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        value: _showAds,
                        onChanged: (value) {
                          setState(() {
                            _showAds = value;
                            if (value) {
                              _initializeAds();
                            } else {
                              _bannerAd?.dispose();
                              _interstitialAd?.dispose();
                            }
                          });
                        },
                        activeColor: Colors.blue,
                      ),
                      
                      ListTile(
                        leading: Icon(
                          Icons.info,
                          color: _darkMode ? Colors.white : Colors.black,
                        ),
                        title: Text(
                          'About SupaCave Browser',
                          style: TextStyle(
                            color: _darkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: _darkMode ? Colors.white : Colors.black,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _showAboutDialog();
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Close button
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _darkMode ? Colors.grey[800] : Colors.grey[200],
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        color: _darkMode ? Colors.white : Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _darkMode ? Colors.grey[800] : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _darkMode ? Colors.white : Colors.black, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: _darkMode ? Colors.white : Colors.black,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showBookmarks() {
    // Implement bookmarks functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bookmarks feature coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _darkMode ? Colors.grey[900] : Colors.white,
        title: Text(
          'Browser History',
          style: TextStyle(color: _darkMode ? Colors.white : Colors.black),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: _history.isEmpty
              ? Center(
                  child: Text(
                    'No history yet',
                    style: TextStyle(color: _darkMode ? Colors.grey[400] : Colors.grey[600]),
                  ),
                )
              : ListView.builder(
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final url = _history.reversed.toList()[index];
                    return ListTile(
                      leading: const Icon(Icons.history, size: 20),
                      title: Text(
                        url.length > 40 ? '${url.substring(0, 40)}...' : url,
                        style: TextStyle(
                          color: _darkMode ? Colors.white : Colors.black,
                          fontSize: 12,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        onPressed: () => _loadUrl(url),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _loadUrl(url);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: _darkMode ? Colors.white : Colors.black),
            ),
          ),
          if (_history.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  _history.clear();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('History cleared'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text(
                'Clear All',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  void _showDownloads() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Downloads feature coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _sharePage() {
    if (_currentUrl.isNotEmpty) {
      // Implement share functionality
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Share: $_currentUrl'),
          action: SnackBarAction(
            label: 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _currentUrl));
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No page to share'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _printPage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Print feature coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _scanQRCode() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('QR Code scanner coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _translatePage() {
    if (_currentUrl.isNotEmpty) {
      final translateUrl = 'https://translate.google.com/translate?hl=en&sl=auto&tl=en&u=${Uri.encodeComponent(_currentUrl)}';
      _loadUrl(translateUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No page to translate'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _darkMode ? Colors.grey[900] : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Browser Settings',
                    style: TextStyle(
                      color: _darkMode ? Colors.white : Colors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Search Engine
                  Text(
                    'Default Search Engine',
                    style: TextStyle(
                      color: _darkMode ? Colors.white : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: _defaultSearchEngine,
                    isExpanded: true,
                    items: _searchEngines.entries.map((entry) {
                      return DropdownMenuItem(
                        value: entry.key,
                        child: Row(
                          children: [
                            Icon(entry.value['icon'] as IconData, 
                                color: entry.value['color'] as Color),
                            const SizedBox(width: 8),
                            Text(entry.value['name'] as String,
                                style: TextStyle(color: _darkMode ? Colors.white : Colors.black)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _defaultSearchEngine = value!;
                      });
                    },
                    dropdownColor: _darkMode ? Colors.grey[800] : Colors.white,
                    style: TextStyle(color: _darkMode ? Colors.white : Colors.black),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Settings toggles
                  SwitchListTile(
                    title: Text(
                      'JavaScript',
                      style: TextStyle(color: _darkMode ? Colors.white : Colors.black),
                    ),
                    value: _javascriptEnabled,
                    onChanged: (value) {
                      setState(() {
                        _javascriptEnabled = value;
                        _controller?.setJavaScriptMode(
                          value ? JavaScriptMode.unrestricted : JavaScriptMode.disabled,
                        );
                      });
                    },
                    activeColor: Colors.blue,
                  ),
                  
                  SwitchListTile(
                    title: Text(
                      'Enable Ad Block',
                      style: TextStyle(color: _darkMode ? Colors.white : Colors.black),
                    ),
                    value: _enableAdBlock,
                    onChanged: (value) {
                      setState(() {
                        _enableAdBlock = value;
                        if (value) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ad Block enabled'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      });
                    },
                    activeColor: Colors.blue,
                  ),
                  
                  // Ad frequency
                  const SizedBox(height: 20),
                  Text(
                    'Ad Frequency',
                    style: TextStyle(
                      color: _darkMode ? Colors.white : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Slider(
                    value: _adFrequency.toDouble(),
                    min: 3,
                    max: 10,
                    divisions: 7,
                    label: 'Every $_adFrequency navigations',
                    onChanged: (value) {
                      setState(() {
                        _adFrequency = value.toInt();
                      });
                    },
                    activeColor: Colors.blue,
                    inactiveColor: _darkMode ? Colors.grey[700] : Colors.grey[300],
                  ),
                  
                  // Clear data
                  const SizedBox(height: 20),
                  ListTile(
                    leading: Icon(
                      Icons.delete_sweep,
                      color: _darkMode ? Colors.white : Colors.black,
                    ),
                    title: Text(
                      'Clear Browser Data',
                      style: TextStyle(
                        color: _darkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: _darkMode ? Colors.grey[900] : Colors.white,
                          title: Text(
                            'Clear Browser Data',
                            style: TextStyle(color: _darkMode ? Colors.white : Colors.black),
                          ),
                          content: Text(
                            'This will clear history, cookies, and cache. Continue?',
                            style: TextStyle(color: _darkMode ? Colors.white : Colors.black),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Cancel',
                                style: TextStyle(color: _darkMode ? Colors.white : Colors.black),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _history.clear();
                                });
                                _controller?.clearCache();
                                Navigator.pop(context);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Browser data cleared'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                              child: const Text(
                                'Clear',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 30),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: _darkMode ? Colors.white : Colors.black,
                        ),
                        child: const Text('Close'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Settings saved'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _darkMode ? Colors.grey[900] : Colors.white,
        title: Row(
          children: [
            Icon(
              Icons.public,
              color: Colors.blue,
              size: 30,
            ),
            const SizedBox(width: 12),
            Text(
              'SupaCave Browser',
              style: TextStyle(
                color: _darkMode ? Colors.white : Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version: 2.0.0',
              style: TextStyle(
                color: _darkMode ? Colors.white : Colors.black,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A fast, secure, and modern web browser with advanced features.',
              style: TextStyle(
                color: _darkMode ? Colors.grey[400] : Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Features:',
              style: TextStyle(
                color: _darkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...['• Desktop Mode', '• Ad Block', '• Quick Apps', '• Dark Mode', '• Secure Browsing']
                .map((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        feature,
                        style: TextStyle(
                          color: _darkMode ? Colors.grey[300] : Colors.grey[700],
                          fontSize: 12,
                        ),
                      ),
                    ))
                ,
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: _darkMode ? Colors.white : Colors.black),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadUrl('https://github.com');
            },
            child: const Text(
              'Website',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: _darkMode ? Colors.black : Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            // URL Bar
            _buildUrlBar(),
            
            // Search suggestions
            _buildSearchSuggestions(),
            
            // Progress indicator
            if (_isLoading)
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.transparent,
                color: Colors.blue,
                minHeight: 2,
              ),
            
            // WebView or Homepage
            Expanded(
              child: Stack(
                children: [
                  // Homepage
                  if (_showHomepage)
                    _buildHomepage(),
                  
                  // WebView
                  if (!_showHomepage && _controller != null)
                    WebViewWidget(controller: _controller!),
                  
                  // Empty state
                  if (!_showHomepage && _controller == null)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.public,
                            size: 80,
                            color: _darkMode ? Colors.grey[700] : Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'SupaCave Browser',
                            style: TextStyle(
                              color: _darkMode ? Colors.white : Colors.black,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Loading browser...',
                            style: TextStyle(
                              color: _darkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 20),
                          CircularProgressIndicator(
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            // Bottom banner ad
            _buildBannerAd(),
          ],
        ),
      ),
      
      // Floating Action Button - Now serves as ENTER/SUBMIT button
floatingActionButton: SizedBox(
        width: 24, // Adjust width
        height: 24, // Adjust height
        child: FloatingActionButton(
          backgroundColor: Colors.blue,
          elevation: 2,
          onPressed: () {
            if (_urlController.text.isNotEmpty) {
              _loadUrl(_urlController.text);
            } else {
              setState(() {
                _showHomepage = true;
              });
            }
            HapticFeedback.lightImpact();
          },
          child:
              _urlController.text.isEmpty
                  ? const Icon(Icons.home, color: Colors.white, size: 18)
                  : const Icon(Icons.search, color: Colors.white, size: 18),
        ),
      ),
    );
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _urlController.dispose();
    _urlFocusNode.dispose();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }
}
