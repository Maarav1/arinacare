// news_api_screen.dart - COMPLETELY REWRITTEN WITH FIXES
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

// ----------------------- Responsive Wrapper -----------------------
class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.maxWidth = 900,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return child;
    }

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: child,
      ),
    );
  }
}

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
      publishedAt: DateTime.parse(
        json['publishedAt'] ?? DateTime.now().toString(),
      ),
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

  // Selected source - DEFAULT TO AL JAZEERA
  String _selectedSource = 'al-jazeera-english';

  // Caching
  SharedPreferences? _prefs;
  final Map<String, List<Article>> _cache = {};
  Map<String, DateTime> _cacheTimestamps = {};
  final Duration _cacheDuration = const Duration(minutes: 10);

  // ALL WORKING SOURCES (removed NTV and KBC)
  final List<Map<String, dynamic>> _sources = [
    {
      'id': 'al-jazeera-english',
      'name': 'Al Jazeera',
      'logo': '🇶🇦',
      'country': 'qa',
      'hasLiveTV': true,
      'liveUrl': 'https://www.aljazeera.com/live',
    },
    {
      'id': 'bbc-news',
      'name': 'BBC News',
      'logo': '🇬🇧',
      'country': 'gb',
      'hasLiveTV': true,
      'liveUrl': 'https://www.bbc.co.uk/iplayer/live/bbcnews',
    },
    {
      'id': 'cnn',
      'name': 'CNN',
      'logo': '🇺🇸',
      'country': 'us',
      'hasLiveTV': true,
      'liveUrl': 'https://edition.cnn.com/live-tv',
    },
    {
      'id': 'reuters',
      'name': 'Reuters',
      'logo': '🌐',
      'country': 'us',
      'hasLiveTV': false,
    },
    {
      'id': 'deutsche-welle',
      'name': 'DW English',
      'logo': '🇩🇪',
      'country': 'de',
      'hasLiveTV': true,
      'liveUrl': 'https://www.dw.com/en/tv/s-10002',
    },
    {
      'id': 'france-24',
      'name': 'France 24',
      'logo': '🇫🇷',
      'country': 'fr',
      'hasLiveTV': true,
      'liveUrl': 'https://www.france24.com/en/live',
    },
    {
      'id': 'nhk-world',
      'name': 'NHK World',
      'logo': '🇯🇵',
      'country': 'jp',
      'hasLiveTV': true,
      'liveUrl': 'https://www3.nhk.or.jp/nhkworld/en/live',
    },
    {
      'id': 'sky-news',
      'name': 'Sky News',
      'logo': '☁️',
      'country': 'gb',
      'hasLiveTV': true,
      'liveUrl': 'https://news.sky.com/watch-live',
    },
    {
      'id': 'channel-newsasia',
      'name': 'CNA',
      'logo': '🇸🇬',
      'country': 'sg',
      'hasLiveTV': true,
      'liveUrl': 'https://www.channelnewsasia.com/watch',
    },
    {
      'id': 'abc-news',
      'name': 'ABC News',
      'logo': '🇦🇺',
      'country': 'au',
      'hasLiveTV': true,
      'liveUrl': 'https://www.abc.net.au/news/live',
    },
    {
      'id': 'cbc-news',
      'name': 'CBC News',
      'logo': '🇨🇦',
      'country': 'ca',
      'hasLiveTV': true,
      'liveUrl': 'https://www.cbc.ca/player/news',
    },
    {
      'id': 'fox-news',
      'name': 'Fox News',
      'logo': '🦊',
      'country': 'us',
      'hasLiveTV': true,
      'liveUrl': 'https://www.foxnews.com/live',
    },
    {
      'id': 'nbc-news',
      'name': 'NBC News',
      'logo': '📺',
      'country': 'us',
      'hasLiveTV': true,
      'liveUrl': 'https://www.nbcnews.com/now',
    },
    {
      'id': 'the-washington-post',
      'name': 'Washington Post',
      'logo': '📰',
      'country': 'us',
      'hasLiveTV': false,
    },
    {
      'id': 'the-new-york-times',
      'name': 'New York Times',
      'logo': '🗽',
      'country': 'us',
      'hasLiveTV': false,
    },
    // KENYAN SOURCES - REMOVED NTV AND KBC (they don't work)
    {
      'id': 'nation',
      'name': 'Daily Nation',
      'logo': '🇰🇪',
      'country': 'ke',
      'hasLiveTV': false,
    },
    {
      'id': 'the-standard',
      'name': 'The Standard',
      'logo': '📰',
      'country': 'ke',
      'hasLiveTV': false,
    },
    {
      'id': 'business-daily',
      'name': 'Business Daily',
      'logo': '💼',
      'country': 'ke',
      'hasLiveTV': false,
    },
    {
      'id': 'the-star',
      'name': 'The Star',
      'logo': '⭐',
      'country': 'ke',
      'hasLiveTV': false,
    },
    // KENYAN TV SOURCES - KEEP ONLY WORKING ONES (Citizen TV and K24 TV)
    {
      'id': 'citizen-tv',
      'name': 'Citizen TV',
      'logo': '📺',
      'country': 'ke',
      'hasLiveTV': true,
      'liveUrl': 'https://citizentv.co.ke/live/',
    },
    {
      'id': 'k24-tv',
      'name': 'K24 TV',
      'logo': '2️⃣4️⃣',
      'country': 'ke',
      'hasLiveTV': true,
      'liveUrl': 'https://www.k24tv.co.ke/live-streaming/',
    },
  ];

  // Sources with Live TV (for quick access)
  List<Map<String, dynamic>> get _liveTVSources {
    return _sources.where((source) => source['hasLiveTV'] == true).toList();
  }

  // AdMob configuration
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  Timer? _interstitialTimer;
  InterstitialAd? _interstitialAd;
  int _adCounter = 0;

  // WebView for full articles
  bool _showWebView = false;
  bool _isLiveTVMode = false;
  WebViewController? _webViewController;
  bool _isWebViewLoading = false;

  // Refresh controller
  final RefreshController _refreshController = RefreshController(
    initialRefresh: false,
  );

  // Drawer state
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _refreshController.dispose();
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
    if (kIsWeb) {
      // On web: proxy handles the key server-side — no key needed in app
      _newsApiKey = 'proxy';
      return;
    }
    try {
      _newsApiKey = dotenv.get('NEWS_API_KEY');

      if (_newsApiKey.isEmpty) {
        setState(() {
          _hasError = true;
          _errorMessage =
              'News API key not configured. Please check your .env file.';
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
    return 'news:$_selectedSource';
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
        'timestamps': _cacheTimestamps.map(
          (k, v) => MapEntry(k, v.toIso8601String()),
        ),
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

      // Check if it's a search term (Citizen TV, K24 TV)
      final isSearchSource =
          _selectedSource == 'citizen-tv' || _selectedSource == 'k24-tv';

      if (kIsWeb) {
        // ===== WEB: Use Cloud Function proxy =====
        url =
            isSearchSource
                ? 'https://us-central1-lifematters-c466d.cloudfunctions.net/newsProxy?q=${Uri.encodeComponent(_sources.firstWhere((s) => s['id'] == _selectedSource)['name'])}&pageSize=30&sortBy=publishedAt'
                : 'https://us-central1-lifematters-c466d.cloudfunctions.net/newsProxy?sources=$_selectedSource&pageSize=30';
      } else {
        // ===== MOBILE: Direct NewsAPI call =====
        if (isSearchSource) {
          final sourceName =
              _sources.firstWhere((s) => s['id'] == _selectedSource)['name'];
          url =
              '$_baseUrl/everything?q=$sourceName&apiKey=$_newsApiKey&pageSize=30&sortBy=publishedAt';
        } else {
          url =
              '$_baseUrl/top-headlines?sources=$_selectedSource&apiKey=$_newsApiKey&pageSize=30';
        }
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

  void _changeSource(String sourceId) {
    setState(() {
      _selectedSource = sourceId;
    });
    _loadNews();
    Navigator.pop(context);
  }

  void _openFullArticle(String url) {
    _isLiveTVMode = false;
    _webViewController =
        WebViewController()
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
    _webViewController =
        WebViewController()
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
          const Icon(Icons.error_outline, size: 64, color: Colors.grey),
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
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
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
                height: kIsWeb ? 300 : 180, // ← CHANGE THIS LINE
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
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArticleItem(Article article) {
    final sourceHasLiveTV = _checkIfSourceHasLiveTV(article.sourceName);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    height: kIsWeb ? 300 : 200, // ← CHANGE THIS LINE
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) => Container(
                          height: kIsWeb ? 300 : 200, // ← CHANGE THIS LINE
                          color: Colors.grey.shade800,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.blue,
                            ),
                          ),
                        ),
                    errorWidget:
                        (context, url, error) => Container(
                          height: kIsWeb ? 300 : 200, // ← CHANGE THIS LINE
                          color: Colors.grey.shade800,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.article, size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text(
                                'Image not available',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                  ),
                  if (sourceHasLiveTV)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final liveUrl = _getLiveTVUrl(article.sourceName);
                          if (liveUrl.isNotEmpty) _openLiveTV(liveUrl);
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Row(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat(
                            'MMM dd, HH:mm',
                          ).format(article.publishedAt),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _shareArticle(article),
                          icon: const Icon(
                            Icons.share,
                            color: Colors.blue,
                            size: 20,
                          ),
                          tooltip: 'Share',
                        ),
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
                if (sourceHasLiveTV)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final liveUrl = _getLiveTVUrl(article.sourceName);
                        if (liveUrl.isNotEmpty) _openLiveTV(liveUrl);
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
    for (var source in _sources) {
      if (source['name']?.toString().toLowerCase().contains(lowerName) ==
          true) {
        return source['hasLiveTV'] == true;
      }
    }
    return false;
  }

  String _getLiveTVUrl(String sourceName) {
    final lowerName = sourceName.toLowerCase();
    for (var source in _sources) {
      if (source['name']?.toString().toLowerCase().contains(lowerName) ==
          true) {
        return source['liveUrl']?.toString() ?? '';
      }
    }
    return '';
  }

  Color _getSourceColor(String sourceName) {
    final lowerName = sourceName.toLowerCase();
    if (lowerName.contains('al jazeera')) return Colors.blue.shade900;
    if (lowerName.contains('bbc')) return Colors.red.shade900;
    if (lowerName.contains('cnn')) return Colors.red;
    if (lowerName.contains('reuters')) return Colors.orange.shade800;
    if (lowerName.contains('dw')) return Colors.blue.shade700;
    if (lowerName.contains('france')) return Colors.blue.shade600;
    if (lowerName.contains('nhk')) return Colors.green.shade800;
    if (lowerName.contains('sky')) return Colors.blue.shade500;
    if (lowerName.contains('cna')) return Colors.red.shade700;
    if (lowerName.contains('abc')) return Colors.blue;
    if (lowerName.contains('cbc')) return Colors.red.shade600;
    if (lowerName.contains('fox')) return Colors.blue.shade700;
    if (lowerName.contains('nbc')) return Colors.blue.shade600;
    if (lowerName.contains('washington')) return Colors.blueGrey;
    if (lowerName.contains('new york')) return Colors.black;
    if (lowerName.contains('nation')) return Colors.green.shade800;
    if (lowerName.contains('standard')) return Colors.blue;
    if (lowerName.contains('business daily')) return Colors.amber.shade800;
    if (lowerName.contains('star')) return Colors.yellow.shade700;
    if (lowerName.contains('citizen')) return Colors.orange.shade800;
    if (lowerName.contains('k24')) return Colors.purple;
    return Colors.grey.shade700;
  }

  String _getSourceEmoji(String sourceName) {
    final lowerName = sourceName.toLowerCase();
    if (lowerName.contains('al jazeera')) return '🇶🇦';
    if (lowerName.contains('bbc')) return '🇬🇧';
    if (lowerName.contains('cnn')) return '🇺🇸';
    if (lowerName.contains('reuters')) return '🌐';
    if (lowerName.contains('dw')) return '🇩🇪';
    if (lowerName.contains('france')) return '🇫🇷';
    if (lowerName.contains('nhk')) return '🇯🇵';
    if (lowerName.contains('sky')) return '☁️';
    if (lowerName.contains('cna')) return '🇸🇬';
    if (lowerName.contains('abc')) return '🇦🇺';
    if (lowerName.contains('cbc')) return '🇨🇦';
    if (lowerName.contains('fox')) return '🦊';
    if (lowerName.contains('nbc')) return '📺';
    if (lowerName.contains('washington')) return '📰';
    if (lowerName.contains('new york')) return '🗽';
    if (lowerName.contains('nation')) return '🇰🇪';
    if (lowerName.contains('standard')) return '📰';
    if (lowerName.contains('business daily')) return '💼';
    if (lowerName.contains('star')) return '⭐';
    if (lowerName.contains('citizen')) return '📺';
    if (lowerName.contains('k24')) return '2️⃣4️⃣';
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
      body:
          _webViewController != null
              ? WebViewWidget(controller: _webViewController!)
              : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.grey.shade900,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
            width: double.infinity,
            color: Colors.black,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📰 News Sources',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select a source to read news',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _sources.length,
              itemBuilder: (context, index) {
                final source = _sources[index];
                final isSelected = _selectedSource == source['id'];
                final hasLiveTV = source['hasLiveTV'] == true;

                return ListTile(
                  leading: Text(
                    source['logo']?.toString() ?? '📰',
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(
                    source['name']?.toString() ?? '',
                    style: TextStyle(
                      color: isSelected ? Colors.blue : Colors.white,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing:
                      hasLiveTV
                          ? const Icon(
                            Icons.live_tv,
                            color: Colors.red,
                            size: 20,
                          )
                          : null,
                  selected: isSelected,
                  selectedTileColor: Colors.blue..withValues(alpha: 30),
                  onTap: () => _changeSource(source['id']!),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border(top: BorderSide(color: Colors.grey.shade800)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey.shade400, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${_sources.length} sources available',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTVPopup() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.live_tv, color: Colors.red, size: 28),
      tooltip: 'Watch Live TV',
      offset: const Offset(0, 50),
      itemBuilder: (context) {
        return _liveTVSources.map((source) {
          return PopupMenuItem<String>(
            value: source['liveUrl']?.toString() ?? '',
            child: Row(
              children: [
                Text(
                  source['logo']?.toString() ?? '📺',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    source['name']?.toString() ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(Icons.live_tv, color: Colors.red, size: 16),
              ],
            ),
          );
        }).toList();
      },
      onSelected: (liveUrl) {
        if (liveUrl.isNotEmpty) _openLiveTV(liveUrl);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showWebView) {
      return _buildWebView();
    }

    // Get current source name for title
    final currentSource = _sources.firstWhere(
      (s) => s['id'] == _selectedSource,
      orElse: () => _sources.first,
    );
    final sourceName = currentSource['name'] ?? 'News';
    final sourceLogo = currentSource['logo'] ?? '📰';

    // Web layout
    if (kIsWeb) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.black,
        drawer: _buildDrawer(),
        appBar: AppBar(
          title: Row(
            children: [
              Text('$sourceLogo ', style: const TextStyle(fontSize: 20)),
              Text(
                '$sourceName News',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          actions: [_buildLiveTVPopup(), const SizedBox(width: 8)],
        ),
        body: SafeArea(
          child: ResponsiveWrapper(
            maxWidth: 900,
            child: Column(
              children: [
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
                    child:
                        _isLoading
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
                                    onPressed: _loadNews,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                    ),
                                    child: const Text(
                                      'Retry',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 60),
                              itemCount: _articles.length,
                              itemBuilder:
                                  (context, index) =>
                                      _buildArticleItem(_articles[index]),
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar:
            _isBannerAdLoaded && _bannerAd != null
                ? Container(
                  height: _bannerAd!.size.height.toDouble(),
                  color: Colors.black,
                  child: AdWidget(ad: _bannerAd!),
                )
                : Container(
                  height: 60,
                  color: Colors.black,
                  child: const Center(
                    child: Text(
                      '📰 Global News Hub',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ),
                ),
      );
    }

    // Mobile layout (original)
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.black,
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: Row(
          children: [
            Text('$sourceLogo ', style: const TextStyle(fontSize: 20)),
            Text(
              '$sourceName News',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [_buildLiveTVPopup(), const SizedBox(width: 8)],
      ),
      body: Column(
        children: [
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
              child:
                  _isLoading
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
                              onPressed: _loadNews,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                              child: const Text(
                                'Retry',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 60),
                        itemCount: _articles.length,
                        itemBuilder:
                            (context, index) =>
                                _buildArticleItem(_articles[index]),
                      ),
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          _isBannerAdLoaded && _bannerAd != null
              ? Container(
                height: _bannerAd!.size.height.toDouble(),
                color: Colors.black,
                child: AdWidget(ad: _bannerAd!),
              )
              : Container(
                height: 60,
                color: Colors.black,
                child: const Center(
                  child: Text(
                    '📰 Global News Hub',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ),
              ),
    );
  }
}
