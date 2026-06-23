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

  const BrowserScreen({super.key, this.initialUrl});

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
  bool _showSearchSuggestions = false;
  final List<String> _history = [];
  int _navigationCount = 0;

  // AdMob
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isBannerAdLoaded = false;
  bool _isInterstitialAdLoaded = false;

  // User agent
  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 10; ArinaCave Browser) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

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

  // Quick apps with categories
  static const List<Map<String, dynamic>> _quickApps = [
    // AI & Tools
    {
      'name': 'DeepSeek',
      'url': 'https://chat.deepseek.com',
      'icon': Icons.psychology,
      'color': Colors.deepPurple,
      'description': 'AI Assistant',
      'category': 'AI',
    },
    {
      'name': 'ChatGPT',
      'url': 'https://chat.openai.com',
      'icon': Icons.smart_toy,
      'color': Colors.green,
      'description': 'AI Assistant',
      'category': 'AI',
    },
    {
      'name': 'Google',
      'url': 'https://www.google.com',
      'icon': Icons.search,
      'color': Colors.blue,
      'description': 'Search the web',
      'category': 'Search',
    },
    // Social Media
    {
      'name': 'TikTok',
      'url': 'https://www.tiktok.com',
      'icon': Icons.music_note,
      'color': Colors.black,
      'description': 'Short videos',
      'category': 'Social',
    },
    {
      'name': 'Instagram',
      'url': 'https://www.instagram.com',
      'icon': Icons.camera_alt,
      'color': Colors.pink,
      'description': 'Photo sharing',
      'category': 'Social',
    },
    {
      'name': 'Twitter/X',
      'url': 'https://twitter.com',
      'icon': Icons.chat,
      'color': Colors.blue,
      'description': 'Social media',
      'category': 'Social',
    },
    {
      'name': 'Reddit',
      'url': 'https://www.reddit.com',
      'icon': Icons.forum,
      'color': Colors.orange,
      'description': 'Online community',
      'category': 'Social',
    },
    {
      'name': 'Facebook',
      'url': 'https://www.facebook.com',
      'icon': Icons.people,
      'color': Colors.blue,
      'description': 'Social network',
      'category': 'Social',
    },
    {
      'name': 'WhatsApp',
      'url': 'https://web.whatsapp.com',
      'icon': Icons.chat_bubble,
      'color': Colors.green,
      'description': 'Messaging',
      'category': 'Social',
    },
    {
      'name': 'Telegram',
      'url': 'https://web.telegram.org',
      'icon': Icons.send,
      'color': Colors.blue,
      'description': 'Secure messaging',
      'category': 'Social',
    },
    // Entertainment
    {
      'name': 'YouTube',
      'url': 'https://www.youtube.com',
      'icon': Icons.play_circle_filled,
      'color': Colors.red,
      'description': 'Watch videos',
      'category': 'Entertainment',
    },
    {
      'name': 'Netflix',
      'url': 'https://www.netflix.com',
      'icon': Icons.movie,
      'color': Colors.red,
      'description': 'Stream movies',
      'category': 'Entertainment',
    },
    {
      'name': 'Spotify',
      'url': 'https://open.spotify.com',
      'icon': Icons.music_note,
      'color': Colors.green,
      'description': 'Music streaming',
      'category': 'Entertainment',
    },
    // Development
    {
      'name': 'GitHub',
      'url': 'https://www.github.com',
      'icon': Icons.code,
      'color': Colors.black,
      'description': 'Code repository',
      'category': 'Development',
    },
    {
      'name': 'Stack Overflow',
      'url': 'https://stackoverflow.com',
      'icon': Icons.help,
      'color': Colors.orange,
      'description': 'Programming Q&A',
      'category': 'Development',
    },
    // Reference
    {
      'name': 'Wikipedia',
      'url': 'https://www.wikipedia.org',
      'icon': Icons.menu_book,
      'color': Colors.grey,
      'description': 'Free encyclopedia',
      'category': 'Reference',
    },
    {
      'name': 'Medium',
      'url': 'https://medium.com',
      'icon': Icons.article,
      'color': Colors.black,
      'description': 'Read articles',
      'category': 'Reading',
    },
    {
      'name': 'Quora',
      'url': 'https://www.quora.com',
      'icon': Icons.question_answer,
      'color': Colors.red,
      'description': 'Q&A community',
      'category': 'Reference',
    },
    // Shopping
    {
      'name': 'Amazon',
      'url': 'https://www.amazon.com',
      'icon': Icons.shopping_cart,
      'color': Colors.orange,
      'description': 'Online shopping',
      'category': 'Shopping',
    },
    // News
    {
      'name': 'BBC News',
      'url': 'https://www.bbc.com/news',
      'icon': Icons.newspaper,
      'color': Colors.red,
      'description': 'World news',
      'category': 'News',
    },
    {
      'name': 'CNN',
      'url': 'https://www.cnn.com',
      'icon': Icons.newspaper,
      'color': Colors.red,
      'description': 'Latest news',
      'category': 'News',
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
  String _selectedCategory = 'All';

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
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.transparent)
          ..setUserAgent(
            _desktopMode
                ? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
                : _userAgent,
          )
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: (progress) {
                if (mounted) {
                  setState(() {
                    _progress = progress / 100;
                    _isLoading = progress < 100;
                  });
                }
              },
              onPageStarted: (url) {
                if (mounted) {
                  setState(() {
                    _currentUrl = url;
                    _isLoading = true;
                    _showHomepage = false;
                    _urlController.text = url;
                    _showSearchSuggestions = false;
                  });
                }
                _navigationCount++;
                _maybeShowInterstitialAd();

                if (_history.isEmpty || _history.last != url) {
                  _history.add(url);
                }
              },
              onPageFinished: (url) async {
                final title = await _controller!.getTitle();
                if (mounted) {
                  setState(() {
                    _currentUrl = url;
                    _isLoading = false;
                    _currentTitle = title ?? 'ArinaCave Browser';
                    _urlController.text = url;
                  });
                }
              },
              onUrlChange: (change) {
                if (mounted) {
                  setState(() {
                    _currentUrl = change.url ?? '';
                    _urlController.text = _currentUrl;
                  });
                }
              },
              onNavigationRequest: (request) {
                if (request.url.startsWith('mailto:') ||
                    request.url.startsWith('tel:') ||
                    request.url.startsWith('sms:')) {
                  _launchExternalUrl(request.url);
                  return NavigationDecision.prevent;
                }

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
            ),
          )
          ..addJavaScriptChannel(
            'ArinaCave',
            onMessageReceived: (JavaScriptMessage message) {
              if (kDebugMode) {
                print('JavaScript: ${message.message}');
              }
            },
          );

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
          if (mounted) {
            setState(() => _isBannerAdLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
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
        },
        onAdFailedToLoad: (error) {},
      ),
    );
  }

  void _maybeShowInterstitialAd() {
    if (_showAds &&
        _isInterstitialAdLoaded &&
        _navigationCount % _adFrequency == 0 &&
        _navigationCount > 0) {
      _interstitialAd?.show();
      _loadInterstitialAd();
    }
  }

  Future<void> _loadUrl(String input) async {
    if (input.isEmpty) return;

    String finalUrl = input.trim();

    if (!finalUrl.contains('.') || finalUrl.contains(' ')) {
      final engine = _searchEngines[_defaultSearchEngine]!;
      finalUrl = '${engine['url']}${Uri.encodeComponent(finalUrl)}';
    } else if (!finalUrl.startsWith('http://') &&
        !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }

    try {
      await _controller!.loadRequest(Uri.parse(finalUrl));
      if (mounted) {
        setState(() {
          _showSearchSuggestions = false;
          _showHomepage = false;
        });
      }
      HapticFeedback.lightImpact();
    } catch (e) {
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
      }
    } catch (e) {
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
      builder:
          (context) => AlertDialog(
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
                  style: TextStyle(
                    color: _darkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _launchExternalUrl(url);
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

  List<String> get _categories {
    final cats =
        _quickApps.map((app) => app['category'] as String).toSet().toList();
    cats.sort();
    return cats;
  }

  List<Map<String, dynamic>> get _filteredApps {
    if (_selectedCategory == 'All') {
      return _quickApps;
    }
    return _quickApps
        .where((app) => app['category'] == _selectedCategory)
        .toList();
  }

  int _getGridColumns() {
    final width = MediaQuery.of(context).size.width;
    if (width < 400) return 3;
    if (width < 600) return 4;
    if (width < 900) return 5;
    if (width < 1200) return 6;
    return 8;
  }

  Widget _buildHomepage() {
    return Container(
      color: _darkMode ? Colors.black : Colors.grey[50],
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // Header
          SliverToBoxAdapter(child: _buildHeader()),

          // Search Bar
          SliverToBoxAdapter(child: _buildHomeSearchBar()),

          // Search Suggestions
          if (_showSearchSuggestions)
            SliverToBoxAdapter(child: _buildSearchSuggestions()),

          // Categories
          SliverToBoxAdapter(child: _buildCategoryFilter()),

          // Quick Apps Grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _getGridColumns(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final app = _filteredApps[index];
                return _buildAppCard(app);
              }, childCount: _filteredApps.length),
            ),
          ),

          // Recent History
          if (_history.isNotEmpty)
            SliverToBoxAdapter(child: _buildRecentHistory()),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              _darkMode
                  ? [Colors.deepPurple[900]!, Colors.blue[900]!]
                  : [Colors.deepPurple[100]!, Colors.blue[100]!],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.public,
              size: 50,
              color: _darkMode ? Colors.white : Colors.deepPurple[800],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ArinaCave Browser',
            style: TextStyle(
              color: _darkMode ? Colors.white : Colors.deepPurple[800],
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fast • Secure • Private',
            style: TextStyle(
              color: _darkMode ? Colors.white70 : Colors.deepPurple[700],
              fontSize: 14,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: _darkMode ? Colors.grey[900] : Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _darkMode ? Colors.grey[800] : Colors.grey[200],
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _urlController,
                focusNode: _urlFocusNode,
                style: TextStyle(
                  color: _darkMode ? Colors.white : Colors.black,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search or enter URL',
                  hintStyle: TextStyle(
                    color: _darkMode ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 16,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: _darkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.mic,
                      color: _darkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Voice search coming soon!'),
                        ),
                      );
                    },
                  ),
                ),
                onSubmitted: _loadUrl,
                onTap: () {
                  setState(() => _showSearchSuggestions = true);
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(30),
            ),
            child: IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: _showMainMenu,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final categories = ['All', ..._categories];
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: _darkMode ? Colors.grey[900] : Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                category,
                style: TextStyle(
                  color:
                      isSelected
                          ? Colors.white
                          : (_darkMode ? Colors.white70 : Colors.grey[700]),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedCategory = category);
                HapticFeedback.lightImpact();
              },
              backgroundColor: _darkMode ? Colors.grey[800] : Colors.grey[200],
              selectedColor: Colors.blue,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppCard(Map<String, dynamic> app) {
    return GestureDetector(
      onTap: () => _loadUrl(app['url']),
      onLongPress: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${app['name']}: ${app['description']}'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: _darkMode ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((_darkMode ? 0.3 : 0.08) as int),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (app['color'] as Color).withValues(),
                    app['color'] as Color,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                app['icon'] as IconData,
                color: Colors.white,
                size: 30,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              app['category'] as String,
              style: TextStyle(
                color: _darkMode ? Colors.grey[500] : Colors.grey[500],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _darkMode ? Colors.grey[850]! : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search engine selector
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: _darkMode ? Colors.grey[700]! : Colors.grey[200]!,
                ),
              ),
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
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: _darkMode ? Colors.white : Colors.black,
                  ),
                  onSelected: (value) {
                    setState(() => _defaultSearchEngine = value);
                  },
                  itemBuilder: (context) {
                    return _searchEngines.entries.map((entry) {
                      return PopupMenuItem(
                        value: entry.key,
                        child: Row(
                          children: [
                            Icon(
                              entry.value['icon'] as IconData,
                              color: entry.value['color'] as Color,
                              size: 20,
                            ),
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

          // Suggestions
          ..._quickApps.take(6).map((app) {
            return ListTile(
              leading: Container(
                width: 36,
                height: 36,
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
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                app['description'] as String,
                style: TextStyle(
                  color: _darkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: _darkMode ? Colors.grey[400] : Colors.grey[600],
              ),
              onTap: () {
                _loadUrl(app['url'] as String);
                setState(() => _showSearchSuggestions = false);
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentHistory() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: _darkMode ? Colors.grey[900] : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📜 Recent History',
                style: TextStyle(
                  color: _darkMode ? Colors.white : Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.clear_all,
                  color: _darkMode ? Colors.white70 : Colors.grey[700],
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _history.clear());
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('History cleared'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _history.take(10).length,
              itemBuilder: (context, index) {
                final url = _history.reversed.toList()[index];
                return GestureDetector(
                  onTap: () => _loadUrl(url),
                  child: Container(
                    width: 180,
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
                          color: _darkMode ? Colors.white70 : Colors.grey[700],
                          size: 16,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          url.length > 30 ? '${url.substring(0, 30)}...' : url,
                          style: TextStyle(
                            color:
                                _darkMode ? Colors.white70 : Colors.grey[700],
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
    );
  }

  Widget _buildUrlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _darkMode ? Colors.grey[900]! : Colors.grey[200]!,
        border: Border(
          bottom: BorderSide(
            color: _darkMode ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
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
                  Icons.arrow_back_ios_new,
                  size: 16,
                  color:
                      canGoBack
                          ? (_darkMode ? Colors.white : Colors.black)
                          : (_darkMode ? Colors.grey[600] : Colors.grey[400]),
                ),
                onPressed:
                    canGoBack
                        ? () async {
                          await _controller?.goBack();
                          HapticFeedback.lightImpact();
                        }
                        : null,
                style: IconButton.styleFrom(
                  backgroundColor:
                      _darkMode ? Colors.grey[800] : Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(6),
                  minimumSize: const Size(32, 32),
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
                  Icons.arrow_forward_ios,
                  size: 16,
                  color:
                      canGoForward
                          ? (_darkMode ? Colors.white : Colors.black)
                          : (_darkMode ? Colors.grey[600] : Colors.grey[400]),
                ),
                onPressed:
                    canGoForward
                        ? () async {
                          await _controller?.goForward();
                          HapticFeedback.lightImpact();
                        }
                        : null,
                style: IconButton.styleFrom(
                  backgroundColor:
                      _darkMode ? Colors.grey[800] : Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(6),
                  minimumSize: const Size(32, 32),
                ),
              );
            },
          ),

          // URL bar
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: _darkMode ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                  if (_currentUrl.startsWith('https://'))
                    const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Icon(Icons.lock, size: 14, color: Colors.green),
                    ),
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      focusNode: _urlFocusNode,
                      style: TextStyle(
                        color: _darkMode ? Colors.white : Colors.black,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search or enter URL',
                        hintStyle: TextStyle(
                          color:
                              _darkMode ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 14,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                      maxLines: 1,
                      textInputAction: TextInputAction.go,
                      onSubmitted: _loadUrl,
                      onTap: () {
                        setState(() => _showSearchSuggestions = true);
                      },
                    ),
                  ),
                  // Menu button
                  IconButton(
                    icon: Icon(
                      Icons.more_vert,
                      size: 18,
                      color: _darkMode ? Colors.white : Colors.black,
                    ),
                    onPressed: _showMainMenu,
                    padding: const EdgeInsets.all(4),
                  ),
                ],
              ),
            ),
          ),

          // Refresh/Stop button
          IconButton(
            icon: Icon(
              _isLoading ? Icons.close : Icons.refresh,
              size: 18,
              color: _darkMode ? Colors.white : Colors.black,
            ),
            onPressed:
                _isLoading
                    ? () => _controller?.reload()
                    : () => _controller?.reload(),
            style: IconButton.styleFrom(
              backgroundColor: _darkMode ? Colors.grey[800] : Colors.grey[300],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(6),
              minimumSize: const Size(32, 32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerAd() {
    if (!_showAds || !_isBannerAdLoaded || _bannerAd == null) {
      return Container(
        height: 50,
        color: _darkMode ? Colors.black : Colors.grey[100],
        child: Center(
          child: Text(
            'ArinaCave Browser',
            style: TextStyle(
              color: _darkMode ? Colors.white54 : Colors.grey[600],
              fontSize: 12,
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
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _darkMode ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color:
                            _darkMode ? Colors.grey[800]! : Colors.grey[200]!,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.public,
                        color: _darkMode ? Colors.white : Colors.black,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ArinaCave Browser',
                              style: TextStyle(
                                color: _darkMode ? Colors.white : Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _currentTitle.isNotEmpty
                                  ? _currentTitle
                                  : 'Ready to browse',
                              style: TextStyle(
                                color:
                                    _darkMode
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
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

                // Quick actions grid
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    children: [
                      _buildMenuButton(
                        icon: Icons.bookmark,
                        label: 'Bookmarks',
                        color: Colors.orange,
                        onTap: () {
                          Navigator.pop(context);
                          _showBookmarks();
                        },
                      ),
                      _buildMenuButton(
                        icon: Icons.history,
                        label: 'History',
                        color: Colors.blue,
                        onTap: () {
                          Navigator.pop(context);
                          _showHistory();
                        },
                      ),
                      _buildMenuButton(
                        icon: Icons.download,
                        label: 'Downloads',
                        color: Colors.green,
                        onTap: () {
                          Navigator.pop(context);
                          _showDownloads();
                        },
                      ),
                      _buildMenuButton(
                        icon: Icons.share,
                        label: 'Share',
                        color: Colors.purple,
                        onTap: () {
                          Navigator.pop(context);
                          _sharePage();
                        },
                      ),
                      _buildMenuButton(
                        icon: Icons.qr_code_scanner,
                        label: 'QR Scan',
                        color: Colors.teal,
                        onTap: () {
                          Navigator.pop(context);
                          _scanQRCode();
                        },
                      ),
                      _buildMenuButton(
                        icon: Icons.translate,
                        label: 'Translate',
                        color: Colors.indigo,
                        onTap: () {
                          Navigator.pop(context);
                          _translatePage();
                        },
                      ),
                      _buildMenuButton(
                        icon: Icons.nightlight,
                        label: 'Dark Mode',
                        color: Colors.deepPurple,
                        onTap: () {
                          setState(() => _darkMode = !_darkMode);
                          Navigator.pop(context);
                        },
                      ),
                      _buildMenuButton(
                        icon: Icons.settings,
                        label: 'Settings',
                        color: Colors.grey,
                        onTap: () {
                          Navigator.pop(context);
                          _showSettings();
                        },
                      ),
                    ],
                  ),
                ),

                // Settings toggles
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Desktop Mode',
                          style: TextStyle(
                            color: _darkMode ? Colors.white : Colors.black,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'View websites in desktop version',
                          style: TextStyle(
                            color:
                                _darkMode ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        value: _desktopMode,
                        onChanged: (value) {
                          setState(() {
                            _desktopMode = value;
                            _controller?.setUserAgent(
                              value
                                  ? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
                                  : _userAgent,
                            );
                          });
                        },
                        activeColor: Colors.blue,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Show Ads',
                          style: TextStyle(
                            color: _darkMode ? Colors.white : Colors.black,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'Display ads for free browsing',
                          style: TextStyle(
                            color:
                                _darkMode ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 12,
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
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.info,
                          color: _darkMode ? Colors.white : Colors.black,
                        ),
                        title: Text(
                          'About ArinaCave Browser',
                          style: TextStyle(
                            color: _darkMode ? Colors.white : Colors.black,
                            fontSize: 14,
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

                const SizedBox(height: 20),

                // Close button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _darkMode ? Colors.grey[800] : Colors.grey[200],
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        color: _darkMode ? Colors.white : Colors.black,
                        fontSize: 14,
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
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: _darkMode ? Colors.white70 : Colors.grey[700],
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showBookmarks() {
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
      builder:
          (context) => AlertDialog(
            backgroundColor: _darkMode ? Colors.grey[900] : Colors.white,
            title: Text(
              'Browser History',
              style: TextStyle(color: _darkMode ? Colors.white : Colors.black),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child:
                  _history.isEmpty
                      ? Center(
                        child: Text(
                          'No history yet',
                          style: TextStyle(
                            color:
                                _darkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      )
                      : ListView.builder(
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final url = _history.reversed.toList()[index];
                          return ListTile(
                            leading: const Icon(Icons.history, size: 20),
                            title: Text(
                              url.length > 40
                                  ? '${url.substring(0, 40)}...'
                                  : url,
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
                  style: TextStyle(
                    color: _darkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              if (_history.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() => _history.clear());
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Share: $_currentUrl'),
          action: SnackBarAction(
            label: 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _currentUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('URL copied!'),
                  backgroundColor: Colors.green,
                ),
              );
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
      final translateUrl =
          'https://translate.google.com/translate?hl=en&sl=auto&tl=en&u=${Uri.encodeComponent(_currentUrl)}';
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
                    items:
                        _searchEngines.entries.map((entry) {
                          return DropdownMenuItem(
                            value: entry.key,
                            child: Row(
                              children: [
                                Icon(
                                  entry.value['icon'] as IconData,
                                  color: entry.value['color'] as Color,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  entry.value['name'] as String,
                                  style: TextStyle(
                                    color:
                                        _darkMode ? Colors.white : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() => _defaultSearchEngine = value!);
                    },
                    dropdownColor: _darkMode ? Colors.grey[800] : Colors.white,
                    style: TextStyle(
                      color: _darkMode ? Colors.white : Colors.black,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Settings toggles
                  SwitchListTile(
                    title: Text(
                      'JavaScript',
                      style: TextStyle(
                        color: _darkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    value: _javascriptEnabled,
                    onChanged: (value) {
                      setState(() {
                        _javascriptEnabled = value;
                        _controller?.setJavaScriptMode(
                          value
                              ? JavaScriptMode.unrestricted
                              : JavaScriptMode.disabled,
                        );
                      });
                    },
                    activeColor: Colors.blue,
                  ),

                  SwitchListTile(
                    title: Text(
                      'Enable Ad Block',
                      style: TextStyle(
                        color: _darkMode ? Colors.white : Colors.black,
                      ),
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
                      setState(() => _adFrequency = value.toInt());
                    },
                    activeColor: Colors.blue,
                    inactiveColor:
                        _darkMode ? Colors.grey[700] : Colors.grey[300],
                  ),

                  // Clear data
                  const SizedBox(height: 20),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
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
                        builder:
                            (context) => AlertDialog(
                              backgroundColor:
                                  _darkMode ? Colors.grey[900] : Colors.white,
                              title: Text(
                                'Clear Browser Data',
                                style: TextStyle(
                                  color:
                                      _darkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              content: Text(
                                'This will clear history, cookies, and cache. Continue?',
                                style: TextStyle(
                                  color:
                                      _darkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color:
                                          _darkMode
                                              ? Colors.white
                                              : Colors.black,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() => _history.clear());
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
                          foregroundColor:
                              _darkMode ? Colors.white : Colors.black,
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
      builder:
          (context) => AlertDialog(
            backgroundColor: _darkMode ? Colors.grey[900] : Colors.white,
            title: Row(
              children: [
                Icon(Icons.public, color: Colors.blue, size: 30),
                const SizedBox(width: 12),
                Text(
                  'ArinaCave Browser',
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
                ...[
                  '• Desktop Mode',
                  '• Ad Block',
                  '• Quick Apps',
                  '• Dark Mode',
                  '• Secure Browsing',
                ].map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      feature,
                      style: TextStyle(
                        color: _darkMode ? Colors.grey[300] : Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: TextStyle(
                    color: _darkMode ? Colors.white : Colors.black,
                  ),
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
      backgroundColor: _darkMode ? Colors.black : Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // URL Bar
            _buildUrlBar(),

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
                  if (_controller != null) ...[
                    if (_showHomepage)
                      _buildHomepage()
                    else
                      WebViewWidget(controller: _controller!),
                  ],
                  if (!_showHomepage && _controller == null)
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),

            // Bottom banner ad
            _buildBannerAd(),
          ],
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
