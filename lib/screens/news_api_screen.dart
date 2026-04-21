// news_api_screen.dart - UPDATED WITH FIXES
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewsApiScreen extends StatefulWidget {
  const NewsApiScreen({super.key});

  @override
  State<NewsApiScreen> createState() => _NewsApiScreenState();
}

class Article {
  final String title;
  final String description;
  final String url;
  final String urlToImage;
  final DateTime publishedAt;
  final String sourceName;
  final String author;
  final String content;
  
  Article({
    required this.title,
    required this.description,
    required this.url,
    required this.urlToImage,
    required this.publishedAt,
    required this.sourceName,
    required this.author,
    required this.content,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      title: json['title'] ?? 'No title',
      description: json['description'] ?? 'No description',
      url: json['url'] ?? '',
      urlToImage: json['urlToImage'] ?? '',
      publishedAt: DateTime.parse(json['publishedAt'] ?? DateTime.now().toString()),
      sourceName: json['source']['name'] ?? 'Unknown Source',
      author: json['author'] ?? 'Unknown Author',
      content: json['content'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'url': url,
      'urlToImage': urlToImage,
      'publishedAt': publishedAt.toIso8601String(),
      'sourceName': sourceName,
      'author': author,
      'content': content,
    };
  }
}

class _NewsApiScreenState extends State<NewsApiScreen> {
  // News API configuration
  String _newsApiKey = '';
  final String _baseUrl = 'https://newsapi.org/v2';
  
  // Data management
  List<Article> _articles = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  
  // Filtering and search
  String _selectedCategory = 'world';
  String _selectedCountry = 'gb'; // Default to UK for BBC
  String _selectedSource = 'bbc-news'; // DEFAULT TO BBC ON STARTUP
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;
  
  // Caching
  SharedPreferences? _prefs;
  final Map<String, List<Article>> _cache = {};
  Map<String, DateTime> _cacheTimestamps = {};
  final Duration _cacheDuration = const Duration(minutes: 10);
  
  // Categories with icons
  final List<Map<String, String>> _categories = [
    {'id': 'world', 'name': '🌍 World', 'icon': '🌍'},
    {'id': 'kenya', 'name': '🇰🇪 Kenya', 'icon': '🇰🇪'},
    {'id': 'business', 'name': '💼 Business', 'icon': '💼'},
    {'id': 'technology', 'name': '💻 Tech', 'icon': '💻'},
    {'id': 'sports', 'name': '⚽ Sports', 'icon': '⚽'},
    {'id': 'entertainment', 'name': '🎬 Entertainment', 'icon': '🎬'},
    {'id': 'health', 'name': '🏥 Health', 'icon': '🏥'},
    {'id': 'science', 'name': '🔬 Science', 'icon': '🔬'},
  ];
  
  // ACTUAL NewsAPI sources (verified working) WITH LIVE TV INFO
  final List<Map<String, dynamic>> _internationalSources = [
    // Major Global Networks with Live TV
    {'id': 'bbc-news', 'name': 'BBC News', 'country': 'gb', 'logo': '🇬🇧', 
     'hasLiveTV': true, 'liveUrl': 'https://www.bbc.co.uk/iplayer/live/bbcnews'},
    {'id': 'cnn', 'name': 'CNN', 'country': 'us', 'logo': '🇺🇸',
     'hasLiveTV': true, 'liveUrl': 'https://edition.cnn.com/live-tv'},
    {'id': 'al-jazeera-english', 'name': 'Al Jazeera', 'country': 'qa', 'logo': '🇶🇦',
     'hasLiveTV': true, 'liveUrl': 'https://www.aljazeera.com/live'},
    {'id': 'reuters', 'name': 'Reuters', 'country': 'us', 'logo': '🌐',
     'hasLiveTV': false},
    
    // European Networks with Live TV
    {'id': 'deutsche-welle', 'name': 'DW English', 'country': 'de', 'logo': '🇩🇪',
     'hasLiveTV': true, 'liveUrl': 'https://www.dw.com/en/tv/s-10002'},
    {'id': 'france-24', 'name': 'France 24', 'country': 'fr', 'logo': '🇫🇷',
     'hasLiveTV': true, 'liveUrl': 'https://www.france24.com/en/live'},
    {'id': 'nhk-world', 'name': 'NHK World', 'country': 'jp', 'logo': '🇯🇵',
     'hasLiveTV': true, 'liveUrl': 'https://www3.nhk.or.jp/nhkworld/en/live'},
    {'id': 'sky-news', 'name': 'Sky News', 'country': 'gb', 'logo': '☁️',
     'hasLiveTV': true, 'liveUrl': 'https://news.sky.com/watch-live'},
    
    // Asian Networks with Live TV
    {'id': 'channel-newsasia', 'name': 'CNA', 'country': 'sg', 'logo': '🇸🇬',
     'hasLiveTV': true, 'liveUrl': 'https://www.channelnewsasia.com/watch'},
    {'id': 'abc-news', 'name': 'ABC News', 'country': 'au', 'logo': '🇦🇺',
     'hasLiveTV': true, 'liveUrl': 'https://www.abc.net.au/news/live'},
    {'id': 'cbc-news', 'name': 'CBC News', 'country': 'ca', 'logo': '🇨🇦',
     'hasLiveTV': true, 'liveUrl': 'https://www.cbc.ca/player/news'},
    
    // US Networks
    {'id': 'fox-news', 'name': 'Fox News', 'country': 'us', 'logo': '🦊',
     'hasLiveTV': true, 'liveUrl': 'https://www.foxnews.com/live'},
    {'id': 'nbc-news', 'name': 'NBC News', 'country': 'us', 'logo': '📺',
     'hasLiveTV': true, 'liveUrl': 'https://www.nbcnews.com/now'},
    {'id': 'the-washington-post', 'name': 'Washington Post', 'country': 'us', 'logo': '📰',
     'hasLiveTV': false},
    {'id': 'the-new-york-times', 'name': 'New York Times', 'country': 'us', 'logo': '🗽',
     'hasLiveTV': false},
  ];
  
  // REAL Kenyan sources in NewsAPI with Live TV info
  final List<Map<String, dynamic>> _verifiedKenyanSources = [
    // These are ACTUALLY in NewsAPI
    {'id': 'nation', 'name': 'Daily Nation', 'country': 'ke', 'logo': '🇰🇪',
     'hasLiveTV': false},
    {'id': 'the-standard', 'name': 'The Standard', 'country': 'ke', 'logo': '📰',
     'hasLiveTV': false},
    {'id': 'business-daily', 'name': 'Business Daily', 'country': 'ke', 'logo': '💼',
     'hasLiveTV': false},
    {'id': 'the-star', 'name': 'The Star', 'country': 'ke', 'logo': '⭐',
     'hasLiveTV': false},
  ];
  
  // Kenyan outlets NOT in NewsAPI - we'll use search queries instead
  final List<Map<String, dynamic>> _kenyanSearchTerms = [
    {'term': 'Citizen TV', 'name': 'Citizen TV', 'logo': '📺',
     'hasLiveTV': true, 'liveUrl': 'https://citizentv.co.ke/live/'},
    {'term': 'KBC Kenya', 'name': 'KBC', 'logo': '🏛️',
     'hasLiveTV': true, 'liveUrl': 'https://www.kbc.co.ke/live/'},
    {'term': 'People Daily Kenya', 'name': 'People Daily', 'logo': '👥',
     'hasLiveTV': false},
    {'term': 'NTV Kenya', 'name': 'NTV Kenya', 'logo': '📡',
     'hasLiveTV': true, 'liveUrl': 'https://www.ntv.co.ke/live'},
    {'term': 'K24 TV', 'name': 'K24 TV', 'logo': '2️⃣4️⃣',
     'hasLiveTV': true, 'liveUrl': 'https://www.k24tv.co.ke/live-streaming/'},
  ];
  
  // Sources that have Live TV (for quick access)
  List<Map<String, dynamic>> get _liveTVSources {
    return [
      ..._internationalSources.where((source) => source['hasLiveTV'] == true),
      ..._kenyanSearchTerms.where((source) => source['hasLiveTV'] == true),
    ];
  }
  
  // AdMob configuration
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  Timer? _interstitialTimer;
  InterstitialAd? _interstitialAd;
  int _adCounter = 0;
  
  // WebView for full articles
  bool _showWebView = false;
  bool _isLiveTVMode = false; // Track if we're showing Live TV
  WebViewController? _webViewController;
  bool _isWebViewLoading = false;
  
  // Refresh controller
  final RefreshController _refreshController = RefreshController(
    initialRefresh: false,
  );
  
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }
  
  @override
  void dispose() {
    _refreshController.dispose();
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _interstitialTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _initializeApp() async {
    await _initializeCache();
    _initializeNewsApi();
    _initializeAds();
    await _loadNews();
    _startInterstitialTimer();
  }
  
  Future<void> _initializeCache() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final cachedData = _prefs!.getString('news_cache');
      if (cachedData != null) {
        final data = json.decode(cachedData);
        _cacheTimestamps = (data['timestamps'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, DateTime.parse(value as String)),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Cache initialization error: $e');
    }
  }
  
  void _initializeNewsApi() {
    try {
      _newsApiKey = dotenv.get('NEWS_API_KEY');
      
      if (_newsApiKey.isEmpty) {
        setState(() {
          _hasError = true;
          _errorMessage = 'News API key not configured. Please check your .env file.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load News API configuration.';
        _isLoading = false;
      });
    }
  }
  
  void _initializeAds() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-1472609237394607/8084106825',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          Future.delayed(const Duration(seconds: 10), () {
            if (mounted) _initializeAds();
          });
        },
      ),
    )..load();
    
    _loadInterstitialAd();
  }
  
  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-1472609237394607/3819175757',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _interstitialAd = null;
          Future.delayed(const Duration(seconds: 30), _loadInterstitialAd);
        },
      ),
    );
  }
  
  void _showInterstitialAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          ad.dispose();
          _loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          ad.dispose();
          _loadInterstitialAd();
        },
      );
      _interstitialAd!.show();
      _interstitialAd = null;
    }
  }
  
  void _startInterstitialTimer() {
    _interstitialTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) {
        _showInterstitialAd();
      }
    });
  }
  
  String _buildCacheKey() {
    if (_searchQuery.isNotEmpty) return 'search:$_searchQuery';
    if (_selectedCategory == 'kenya' && _selectedSource != 'all') {
      return 'kenya:$_selectedSource';
    }
    return 'news:$_selectedCategory:$_selectedCountry:$_selectedSource';
  }
  
  List<Article>? _getCachedArticles() {
    final key = _buildCacheKey();
    final timestamp = _cacheTimestamps[key];
    
    if (timestamp != null && 
        DateTime.now().difference(timestamp) < _cacheDuration &&
        _cache[key] != null) {
      return _cache[key]!;
    }
    return null;
  }
  
  void _cacheArticles(List<Article> articles) {
    final key = _buildCacheKey();
    _cache[key] = articles;
    _cacheTimestamps[key] = DateTime.now();
    
    if (_prefs != null) {
      final data = {
        'timestamps': _cacheTimestamps.map((k, v) => MapEntry(k, v.toIso8601String())),
      };
      _prefs!.setString('news_cache', json.encode(data));
    }
  }
  
  Future<void> _loadNews({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }
    
    // Try cache first (unless refreshing)
    if (!isRefresh) {
      final cached = _getCachedArticles();
      if (cached != null) {
        setState(() {
          _articles = cached;
          _isLoading = false;
        });
        return;
      }
    }
    
    try {
      if (_newsApiKey.isEmpty) {
        throw Exception('News API key not configured');
      }
      
      String url;
      
      if (_searchQuery.isNotEmpty) {
        url = '$_baseUrl/everything?q=$_searchQuery&apiKey=$_newsApiKey&pageSize=30&sortBy=publishedAt';
      } 
      else if (_selectedCategory == 'kenya') {
        if (_selectedSource != 'all') {
          final source = _verifiedKenyanSources.firstWhere(
            (s) => s['id'] == _selectedSource,
            orElse: () => {'id': '', 'name': ''},
          );
          
          if (source['id']!.isNotEmpty) {
            url = '$_baseUrl/top-headlines?sources=$_selectedSource&apiKey=$_newsApiKey&pageSize=30';
          } else {
            final searchTerm = _kenyanSearchTerms.firstWhere(
              (s) => s['name'] == _selectedSource,
              orElse: () => {'term': 'Kenya news', 'name': ''},
            )['term'];
            url = '$_baseUrl/everything?q=$searchTerm&apiKey=$_newsApiKey&pageSize=30&sortBy=publishedAt';
          }
        } else {
          url = '$_baseUrl/top-headlines?country=ke&apiKey=$_newsApiKey&pageSize=30';
        }
      }
      else if (_selectedSource != 'all') {
        url = '$_baseUrl/top-headlines?sources=$_selectedSource&apiKey=$_newsApiKey&pageSize=30';
      }
      else {
        url = '$_baseUrl/top-headlines?country=$_selectedCountry&category=$_selectedCategory&apiKey=$_newsApiKey&pageSize=30';
      }
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'ok') {
          List<Article> articles = [];
          
          for (var articleJson in data['articles']) {
            articles.add(Article.fromJson(articleJson));
          }
          
          // Cache the results
          _cacheArticles(articles);
          
          setState(() {
            _articles = articles;
            _hasError = false;
            _isLoading = false;
          });
          
          _adCounter++;
          if (_adCounter % 3 == 0 && !isRefresh) {
            _showInterstitialAd();
          }
        } else {
          throw Exception('API Error: ${data['message']}');
        }
      } else {
        throw Exception('Failed to load news: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    } finally {
      if (isRefresh) {
        _refreshController.refreshCompleted();
      }
    }
  }
  
  void _onRefresh() async {
    await _loadNews(isRefresh: true);
  }
  
  void _onSearchChanged(String value) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.isNotEmpty) {
        setState(() {
          _searchQuery = _searchController.text;
        });
        _loadNews();
      }
    });
  }
  
  void _clearSearch() {
    _searchDebounceTimer?.cancel();
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
    _loadNews();
  }
  
  void _openFullArticle(String url) {
    _isLiveTVMode = false;
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _isWebViewLoading = progress < 100;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _isWebViewLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isWebViewLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
    
    setState(() {
      _showWebView = true;
    });
  }
  
  void _openLiveTV(String liveUrl) {
    _isLiveTVMode = true;
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _isWebViewLoading = progress < 100;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _isWebViewLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isWebViewLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(liveUrl));
    
    setState(() {
      _showWebView = true;
    });
  }
  
  void _closeWebView() {
    _webViewController = null;
    setState(() {
      _showWebView = false;
      _isLiveTVMode = false;
    });
  }
  
  void _shareArticle(Article article) async {
  try {
    final params = ShareParams(
      text: '${article.title}\n\nRead more: ${article.url}',
      subject: 'Check out this news article',
    );

    await SharePlus.instance.share(params);
  } catch (e) {
    // Guard against using context after async gap
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Unable to share article'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
  
  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'Failed to load news',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadNews,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedSource = 'bbc-news';
                _selectedCountry = 'gb';
                _selectedCategory = 'world';
              });
              _loadNews();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Load BBC News',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingWidget() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: MediaQuery.of(context).size.width * 0.7,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          height: 10,
                          width: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          height: 10,
                          width: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildSourceChip(Map<String, dynamic> source, {bool isKenyanSearch = false}) {
    final isSelected = _selectedSource == (isKenyanSearch ? source['name'] : source['id']);
    final hasLiveTV = source['hasLiveTV'] == true;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(source['logo']?.toString() ?? '📰'),
            const SizedBox(width: 6),
            Text(
              source['name']?.toString() ?? '',
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
            if (hasLiveTV) ...[
              const SizedBox(width: 4),
              const Icon(Icons.live_tv, size: 12, color: Colors.red),
            ],
          ],
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedSource = isKenyanSearch ? source['name']!.toString() : source['id']!.toString();
            _selectedCategory = 'world';
          });
          _loadNews();
        },
        backgroundColor: Colors.grey.shade800,
        selectedColor: Colors.blue,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
        ),
      ),
    );
  }
  
  Widget _buildArticleItem(Article article) {
    final sourceHasLiveTV = _checkIfSourceHasLiveTV(article.sourceName);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Article Image
          if (article.urlToImage.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: article.urlToImage,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: Colors.grey.shade800,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      color: Colors.grey.shade800,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.article,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Image not available',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Live TV button overlay
                  if (sourceHasLiveTV)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final liveUrl = _getLiveTVUrl(article.sourceName);
                          if (liveUrl.isNotEmpty) {
                            _openLiveTV(liveUrl);
                          }
                        },
                        icon: const Icon(Icons.live_tv, size: 16),
                        label: const Text('LIVE'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          
          // Article Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Source badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getSourceColor(article.sourceName),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getSourceEmoji(article.sourceName),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        article.sourceName.length > 20
                            ? '${article.sourceName.substring(0, 20)}...'
                            : article.sourceName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (sourceHasLiveTV) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.live_tv, size: 12, color: Colors.red),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Title
                Text(
                  article.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 12),
                
                // Description
                if (article.description.isNotEmpty)
                  Text(
                    article.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                
                const SizedBox(height: 16),
                
                // Footer with date and actions
                Row(
                  children: [
                    // Date
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM dd, HH:mm').format(article.publishedAt),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    
                    const Spacer(),
                    
                    // Action buttons
                    Row(
                      children: [
                        // Share button
                        IconButton(
                          onPressed: () => _shareArticle(article),
                          icon: const Icon(
                            Icons.share,
                            color: Colors.blue,
                            size: 20,
                          ),
                          tooltip: 'Share',
                        ),
                        
                        // Read button
                        ElevatedButton(
                          onPressed: () => _openFullArticle(article.url),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                          ),
                          child: const Text(
                            'Read',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Live TV button (bottom)
                if (sourceHasLiveTV)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final liveUrl = _getLiveTVUrl(article.sourceName);
                        if (liveUrl.isNotEmpty) {
                          _openLiveTV(liveUrl);
                        }
                      },
                      icon: const Icon(Icons.live_tv, size: 16),
                      label: const Text('Watch Live TV'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  bool _checkIfSourceHasLiveTV(String sourceName) {
    final lowerName = sourceName.toLowerCase();
    
    // Check international sources
    for (var source in _internationalSources) {
      if (source['name']?.toString().toLowerCase().contains(lowerName) == true) {
        return source['hasLiveTV'] == true;
      }
    }
    
    // Check Kenyan sources
    for (var source in _kenyanSearchTerms) {
      if (source['name']?.toString().toLowerCase().contains(lowerName) == true) {
        return source['hasLiveTV'] == true;
      }
    }
    
    return false;
  }
  
  String _getLiveTVUrl(String sourceName) {
    final lowerName = sourceName.toLowerCase();
    
    // Check international sources
    for (var source in _internationalSources) {
      if (source['name']?.toString().toLowerCase().contains(lowerName) == true) {
        return source['liveUrl']?.toString() ?? '';
      }
    }
    
    // Check Kenyan sources
    for (var source in _kenyanSearchTerms) {
      if (source['name']?.toString().toLowerCase().contains(lowerName) == true) {
        return source['liveUrl']?.toString() ?? '';
      }
    }
    
    return '';
  }
  
  Color _getSourceColor(String sourceName) {
    if (sourceName.toLowerCase().contains('bbc')) return Colors.red.shade900;
    if (sourceName.toLowerCase().contains('cnn')) return Colors.red;
    if (sourceName.toLowerCase().contains('al jazeera')) return Colors.blue.shade900;
    if (sourceName.toLowerCase().contains('nation')) return Colors.green.shade800;
    if (sourceName.toLowerCase().contains('citizen')) return Colors.orange.shade800;
    if (sourceName.toLowerCase().contains('standard')) return Colors.blue;
    if (sourceName.toLowerCase().contains('kbc')) return Colors.purple;
    if (sourceName.toLowerCase().contains('people')) return Colors.blueGrey;
    return Colors.grey.shade700;
  }
  
  String _getSourceEmoji(String sourceName) {
    final lowerName = sourceName.toLowerCase();
    if (lowerName.contains('bbc')) return '🇬🇧';
    if (lowerName.contains('cnn')) return '🇺🇸';
    if (lowerName.contains('al jazeera')) return '🇶🇦';
    if (lowerName.contains('dw')) return '🇩🇪';
    if (lowerName.contains('france')) return '🇫🇷';
    if (lowerName.contains('nhk')) return '🇯🇵';
    if (lowerName.contains('cna')) return '🇸🇬';
    if (lowerName.contains('nation')) return '🇰🇪';
    if (lowerName.contains('citizen')) return '📺';
    if (lowerName.contains('standard')) return '📰';
    if (lowerName.contains('kbc')) return '🏛️';
    if (lowerName.contains('people')) return '👥';
    return '📰';
  }
  
  Widget _buildWebView() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          _isLiveTVMode ? '📺 Live TV' : '📰 Article',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _closeWebView,
        ),
        actions: [
          if (_isWebViewLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          if (_webViewController != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _webViewController!.reload(),
            ),
          if (_webViewController != null && !_isLiveTVMode)
  IconButton(
    icon: const Icon(Icons.open_in_browser),
    onPressed: () async {
      try {
        final currentUrl = await _webViewController!.currentUrl();
        if (currentUrl != null) {
          await launchUrl(
            Uri.parse(currentUrl),
            mode: LaunchMode.externalApplication,
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open in browser'),
            backgroundColor: Colors.red,
          ),
        );
      }
    },
  ),
        ],
      ),
      body: _webViewController != null
          ? WebViewWidget(controller: _webViewController!)
          : const Center(child: CircularProgressIndicator()),
    );
  }
  
  Widget _buildMainContent() {
    if (_showWebView) {
      return _buildWebView();
    }
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          '📰 Global News',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          // Quick Live TV Access Button
          if (_liveTVSources.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.live_tv, color: Colors.red),
              tooltip: 'Watch Live TV',
              itemBuilder: (context) {
                return _liveTVSources.map((source) {
                  return PopupMenuItem<String>(
                    value: source['liveUrl']?.toString() ?? '',
                    child: Row(
                      children: [
                        Text(source['logo']?.toString() ?? '📺'),
                        const SizedBox(width: 8),
                        Text(source['name']?.toString() ?? ''),
                      ],
                    ),
                  );
                }).toList();
              },
              onSelected: (liveUrl) {
                if (liveUrl.isNotEmpty) {
                  _openLiveTV(liveUrl);
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _NewsSearchDelegate(
                  onSearch: (query) {
                    setState(() {
                      _searchQuery = query;
                    });
                    _loadNews();
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search news...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: _clearSearch,
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade900,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: _onSearchChanged,
              onSubmitted: (_) {
                if (_searchController.text.isNotEmpty) {
                  setState(() {
                    _searchQuery = _searchController.text;
                  });
                  _loadNews();
                }
              },
            ),
          ),
          
          // Quick Categories
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category['id'];
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category['id']!;
                        _selectedSource = category['id'] == 'world' ? 'bbc-news' : 'all';
                        _searchQuery = '';
                        _searchController.clear();
                        _searchDebounceTimer?.cancel();
                      });
                      _loadNews();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [Colors.blue, Colors.blueAccent],
                              )
                            : null,
                        color: isSelected ? null : Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(category['icon']!),
                          const SizedBox(width: 6),
                          Text(
                            category['name']!,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // International Source Selection (only when world category is selected)
          if (_selectedCategory == 'world')
            Column(
              children: [
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.language, size: 14, color: Colors.blue),
                      SizedBox(width: 6),
                      Text(
                        'Select News Source:',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _internationalSources.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildSourceChip({
                          'id': 'all',
                          'name': '🌍 All Sources',
                          'logo': '🌍',
                          'hasLiveTV': false,
                        });
                      }
                      return _buildSourceChip(_internationalSources[index - 1]);
                    },
                  ),
                ),
              ],
            ),
          
          // Kenyan Source Selection (only when Kenya category is selected)
          if (_selectedCategory == 'kenya')
            Column(
              children: [
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 14, color: Colors.green),
                      SizedBox(width: 6),
                      Text(
                        'Verified Kenyan Sources:',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _verifiedKenyanSources.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildSourceChip({
                          'id': 'all',
                          'name': 'All Kenya',
                          'logo': '🇰🇪',
                          'hasLiveTV': false,
                        });
                      }
                      return _buildSourceChip(_verifiedKenyanSources[index - 1]);
                    },
                  ),
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 14, color: Colors.orange),
                      SizedBox(width: 6),
                      Text(
                        'Search-based sources:',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _kenyanSearchTerms.length,
                    itemBuilder: (context, index) {
                      return _buildSourceChip(
                        _kenyanSearchTerms[index], 
                        isKenyanSearch: true
                      );
                    },
                  ),
                ),
              ],
            ),
          
          // News List
          Expanded(
            child: SmartRefresher(
              controller: _refreshController,
              onRefresh: _onRefresh,
              enablePullDown: true,
              enablePullUp: false,
              header: const ClassicHeader(
                completeText: 'Refresh complete',
                refreshingText: 'Loading latest news...',
                releaseText: 'Release to refresh',
                idleText: 'Pull down to refresh',
                textStyle: TextStyle(color: Colors.white),
              ),
              child: _isLoading
                  ? _buildLoadingWidget()
                  : _hasError
                      ? _buildErrorWidget()
                      : _articles.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.article_outlined,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No articles found',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      // This would be handled by the parent widget
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                    ),
                                    child: const Text(
                                      'Try BBC News',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 60),
                              itemCount: _articles.length,
                              itemBuilder: (context, index) {
                                return _buildArticleItem(_articles[index]);
                              },
                            ),
            ),
          ),
        ],
      ),
      
      // Banner Ad at bottom
      bottomNavigationBar: _isBannerAdLoaded && _bannerAd != null
          ? Container(
              height: _bannerAd!.size.height.toDouble(),
              color: Colors.black,
              child: AdWidget(ad: _bannerAd!),
            )
          : Container(
              height: 60,
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '📰 Global News Hub',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'BBC News • Live TV • Multiple Sources',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
  
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'News Filters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              // Quick BBC Button
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedSource = 'bbc-news';
                    _selectedCategory = 'world';
                    _selectedCountry = 'gb';
                  });
                  _loadNews();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.star, color: Colors.yellow),
                label: const Text('Quick: Load BBC News'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade900,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Category Selection
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.grey.shade900,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                dropdownColor: Colors.grey.shade900,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                items: _categories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category['id'],
                    child: Row(
                      children: [
                        Text(category['icon']!),
                        const SizedBox(width: 8),
                        Text(
                          category['name']!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                    _selectedSource = value == 'world' ? 'bbc-news' : 'all';
                  });
                  _loadNews();
                  Navigator.pop(context);
                },
              ),
              
              const SizedBox(height: 16),
              
              // Live TV Quick Access
              const Text(
                'Live TV Channels',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _liveTVSources.take(5).map((source) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final liveUrl = source['liveUrl']?.toString();
                          if (liveUrl != null && liveUrl.isNotEmpty) {
                            _openLiveTV(liveUrl);
                            Navigator.pop(context);
                          }
                        },
                        icon: Text(source['logo']?.toString() ?? '📺'),
                        label: Text(source['name']?.toString() ?? ''),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade900,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategory = 'world';
                          _selectedSource = 'bbc-news'; // Reset to BBC
                          _selectedCountry = 'gb';
                          _searchQuery = '';
                          _searchController.clear();
                        });
                        _loadNews();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade900,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Reset to BBC',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return _buildMainContent();
  }
}

class _NewsSearchDelegate extends SearchDelegate<String> {
  final Function(String) onSearch;
  
  _NewsSearchDelegate({required this.onSearch});
  
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }
  
  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }
  
  @override
  Widget buildResults(BuildContext context) {
    onSearch(query);
    close(context, query);
    return Container();
  }
  
  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = query.isEmpty
        ? [
            'Breaking news',
            'Technology',
            'Business',
            'Sports',
            'Politics',
            'Entertainment',
            'Health',
            'Science',
          ]
        : [
            '$query news',
            'latest $query',
            '$query today',
            '$query 2026',
            '$query Kenya',
            '$query Africa',
            '$query international',
          ];
    
    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: const Icon(Icons.search, color: Colors.grey),
          title: Text(
            suggestions[index],
            style: const TextStyle(color: Colors.white),
          ),
          onTap: () {
            query = suggestions[index];
            showResults(context);
          },
        );
      },
    );
  }
  
  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
      ),
    );
  }
}