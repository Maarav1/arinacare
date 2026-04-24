import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:http/http.dart' as http;
import 'package:rss_dart/dart_rss.dart';
import 'dart:async';
import 'package:arina_cave/services/ad_service.dart';
import 'package:arina_cave/widgets/ad_banner.dart';



class ArinaNewsScreen extends StatefulWidget {
  const ArinaNewsScreen({super.key});

  @override
  State<ArinaNewsScreen> createState() => _ArinaNewsScreenState();
}

class _ArinaNewsScreenState extends State<ArinaNewsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RefreshController _refreshController = RefreshController();
  List<NewsArticle> _breakingNews = [];
  bool _isLoadingBreakingNews = true;
    int _articleViewCount = 0;
  
  // Curated mobile-friendly news sources
  final List<NewsSource> _newsSources = [
    NewsSource(
      name: 'BBC News',
      url: 'https://www.bbc.com/news',
      rssUrl: 'http://feeds.bbci.co.uk/news/rss.xml',
      icon: Icons.public,
      color: Colors.blue,
    ),
    NewsSource(
      name: 'Al Jazeera',
      url: 'https://www.aljazeera.com/mobile',
      rssUrl: 'https://www.aljazeera.com/xml/rss/all.xml',
      icon: Icons.language,
      color: Colors.green,
    ),
    // 1. France 24 English
// Excellent 24/7 coverage with a French/European perspective.
NewsSource(
  name: 'France 24',
  url: 'https://www.france24.com/en/live',
  rssUrl: 'https://www.france24.com/en/rss',
  icon: Icons.public, // Or a custom flag icon
  color: Colors.blueAccent,
),

// 2. NHK World-Japan
// The best source for Asian/Japanese news in English. Very reliable stream.
NewsSource(
  name: 'NHK World',
  url: 'https://www3.nhk.or.jp/nhkworld/en/live/',
  rssUrl: 'https://www3.nhk.or.jp/nhkworld/en/news/list/index.xml',
  icon: Icons.circle, // Resembles the Japanese rising sun
  color: Colors.deepPurpleAccent, // NHK's brand color is often a distinct pink/red
),

// 3. Sky News (UK/International)
// British breaking news, distinct from the BBC.
NewsSource(
  name: 'Sky News',
  url: 'https://news.sky.com/watch-live',
  rssUrl: 'https://feeds.skynews.com/feeds/rss/world.xml',
  icon: Icons.cloud,
  color: Colors.blue,
),

// 4. CNA (Channel News Asia)
// Singapore-based English broadcaster; great for SE Asia business/news.
NewsSource(
  name: 'CNA',
  url: 'https://www.channelnewsasia.com/watch',
  rssUrl: 'https://www.channelnewsasia.com/api/v1/rss-outbound-feed?_format=xml',
  icon: Icons.trending_up, // Focuses heavily on business/markets
  color: Colors.blue,
),
    NewsSource(
      name: 'BBC',
      url: 'https://stream.live.vc.bbcmedia.co.uk/bbc_radio_fourfm',
      rssUrl: 'http://feeds.bbci.co.uk/news/rss.xml',
      icon: Icons.live_tv,
      color: Colors.brown,
    ),
    NewsSource(
      name: 'DW News',
      url: 'https://www.dw.com/en/live-tv/channel-english',
      rssUrl: 'https://rss.dw.com/rdf/rss-en-all',
      icon: Icons.newspaper,
      color: Colors.deepPurpleAccent,
    ),
    // Kenyan Sources
    NewsSource(
      name: 'Nation Kenya',
      url: 'https://nation.africa/kenya',
      rssUrl: 'https://nation.africa/kenya.rss',
      icon: Icons.flag,
      color: Colors.lightBlueAccent,
      isLocal: true,
    ),
    NewsSource(
      name: 'Citizen TV',
      url: 'https://citizen.digital',
      rssUrl: 'https://citizen.digital/rss',
      icon: Icons.tv,
      color: Colors.blue,
      isLocal: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
      });
    });
    _fetchBreakingNews();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  void _showInterstitialIfNeeded() {
    _articleViewCount++;
    if (_articleViewCount % 5 == 0) {
      AdService.instance.showInterstitialAd();
    }
  }

  Future<void> _fetchBreakingNews() async {
    setState(() {
      _isLoadingBreakingNews = true;
    });

    try {
      // This will now get REAL news from BBC RSS
      final articles = await _fetchRealNewsFromRss();
      setState(() {
        _breakingNews = articles;
        _isLoadingBreakingNews = false;
      });
    } catch (e) {
      debugPrint('Error fetching news: $e');
      // Fallback to mock data
      setState(() {
        _breakingNews = _getMockNews();
        _isLoadingBreakingNews = false;
      });
    }
  }

  Future<List<NewsArticle>> _fetchRealNewsFromRss() async {
    try {
      // Primary source: BBC RSS (always free, no API key)
      final response = await http.get(
        Uri.parse('http://feeds.bbci.co.uk/news/rss.xml'),
      );

      if (response.statusCode == 200) {
        return _parseRssFeedWithPackage(response.body, 'BBC News');
      }
    } catch (e) {
      debugPrint('BBC RSS failed: $e');
    }

    // Fallback to Reuters
    try {
      final response = await http.get(
        Uri.parse('http://feeds.reuters.com/reuters/topNews'),
      );
      
      if (response.statusCode == 200) {
        return _parseRssFeedWithPackage(response.body, 'Reuters');
      }
    } catch (e) {
      debugPrint('Reuters RSS failed: $e');
    }

    // Final fallback: mock data
    return _getMockNews();
  }

  List<NewsArticle> _parseRssFeedWithPackage(String xml, String sourceName) {
    final articles = <NewsArticle>[];
    
    try {
      // Use the rss_dart package to parse the XML properly
      final channel = RssFeed.parse(xml);
      
      for (var item in channel.items.take(15)) {
        String? imageUrl;
        
        // Try to extract image from different possible fields
        if (item.media != null && item.media!.contents.isNotEmpty) {
          imageUrl = item.media!.contents.first.url;
        } else if (item.enclosure != null) {
          imageUrl = item.enclosure!.url;
        } else if (item.description != null) {
          // Try to extract image from HTML description
          final imgMatch = RegExp(r'<img[^>]+src="([^"]+)"').firstMatch(item.description!);
          if (imgMatch != null) {
            imageUrl = imgMatch.group(1);
          }
        }
        
        final title = item.title?.trim() ?? 'No title';
        final description = _cleanHtml(item.description ?? '');
        final link = item.link?.trim() ?? 'https://www.example.com';
        final pubDate = item.pubDate?.trim() ?? DateTime.now().toIso8601String();
        
        articles.add(NewsArticle(
          title: title.length > 100 ? '${title.substring(0, 100)}...' : title,
          description: description.length > 150 ? '${description.substring(0, 150)}...' : description,
          url: link,
          imageUrl: imageUrl ?? _getRandomNewsImage(),
          source: sourceName,
          publishedAt: pubDate,
        ));
      }
    } catch (e) {
      debugPrint('RSS parse error for $sourceName: $e');
    }
    
    return articles.isNotEmpty ? articles : _getMockNews();
  }

  String _cleanHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();
  }

  String _getRandomNewsImage() {
    final images = [
      'https://images.unsplash.com/photo-1588681664899-f142ff2dc9b1?w=800', // News
      'https://images.unsplash.com/photo-1518837695005-2083093ee35b?w=800', // Tech
      'https://images.unsplash.com/photo-1592210454359-9043f067919b?w=800', // Weather
      'https://images.unsplash.com/photo-1551650975-87deedd944c3?w=800', // Business
      'https://images.unsplash.com/photo-1466611653911-95081537e5b7?w=800', // Science
    ];
    return images[DateTime.now().millisecondsSinceEpoch % images.length];
  }

  List<NewsArticle> _getMockNews() {
    return [
      NewsArticle(
        title: 'Breaking: Major Tech Conference Announcement',
        description: 'New innovations revealed at annual tech summit',
        url: 'https://www.bbc.com/news/technology',
        imageUrl: 'https://images.unsplash.com/photo-1518837695005-2083093ee35b?w=800',
        source: 'Tech News',
        publishedAt: DateTime.now().toIso8601String(),
      ),
      NewsArticle(
        title: 'Emergency Weather Alert',
        description: 'Severe weather conditions expected in multiple regions',
        url: 'https://www.bbc.com/news/world',
        imageUrl: 'https://images.unsplash.com/photo-1592210454359-9043f067919b?w=800',
        source: 'Weather Channel',
        publishedAt: DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      ),
      NewsArticle(
        title: 'Flutter 3.0 Released with Major Updates',
        description: 'Google announces new features for cross-platform development',
        url: 'https://www.bbc.com/news/technology',
        imageUrl: 'https://images.unsplash.com/photo-1551650975-87deedd944c3?w=800',
        source: 'BBC Technology',
        publishedAt: DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      ),
      NewsArticle(
        title: 'Sustainable Energy Breakthrough',
        description: 'New solar panel technology achieves record efficiency',
        url: 'https://www.bbc.com/news/science',
        imageUrl: 'https://images.unsplash.com/photo-1466611653911-95081537e5b7?w=800',
        source: 'Science Daily',
        publishedAt: DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      ),
      NewsArticle(
        title: 'Global Markets Show Recovery Signs',
        description: 'Stock markets worldwide show positive momentum',
        url: 'https://www.bbc.com/news/business',
        imageUrl: 'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=800',
        source: 'BBC Business',
        publishedAt: DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
      ),
    ];
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text(
        'ArinaCave News',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        tabs: const [
          Tab(icon: Icon(Icons.today), text: 'Daily'),
          Tab(icon: Icon(Icons.new_releases), text: 'Breaking'),
          Tab(icon: Icon(Icons.source), text: 'Sources'),
        ],
      ),
    ),
    body: Column(
      children: [
        // MAIN CONTENT AREA - Takes most of the space
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // TAB 1: Daily News WebView
              _buildDailyNewsTab(),

              // TAB 2: Breaking News
              _buildBreakingNewsTab(),

              // TAB 3: All News Sources
              _buildSourcesTab(),
            ],
          ),
        ),
        
        const AdBanner(),
      ],
    ),
  );
}

  // TAB 1: Daily News (Embedded WebView)
  Widget _buildDailyNewsTab() {
    return Column(
      children: [
        // Source selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.source, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<NewsSource>(
                  value: _newsSources[0],
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _newsSources.map((source) {
                    return DropdownMenuItem<NewsSource>(
                      value: source,
                      child: Text(
                        source.name,
                        style: TextStyle(
                          color: source.isLocal ? Colors.green : null,
                          fontWeight: source.isLocal ? FontWeight.bold : null,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (source) {
                    if (source != null) {
                      _openNewsSource(source);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: WebViewScreen(source: _newsSources[0]),
        ),
      ],
    );
  }

  // TAB 2: Breaking News
  Widget _buildBreakingNewsTab() {
    return SmartRefresher(
      controller: _refreshController,
      enablePullDown: true,
      enablePullUp: false,
      header: const ClassicHeader(),
      onRefresh: () async {
        await _fetchBreakingNews();
        _refreshController.refreshCompleted();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Breaking News Header
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.new_releases, color: Colors.red.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live Breaking News',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Updated every 15 minutes from trusted sources',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showBreakingNewsInfo(),
                    icon: Icon(Icons.info_outline, color: Colors.blue.shade700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Breaking News List
          if (_isLoadingBreakingNews)
            _buildNewsShimmer()
          else if (_breakingNews.isEmpty)
            _buildNewsFallback()
          else
            ..._breakingNews
                .asMap()
                .entries
                .map((entry) => _buildNewsArticleCard(entry.value, entry.key == 0))
                ,
        ],
      ),
    );
  }

  // TAB 3: All News Sources
  Widget _buildSourcesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Curated News Sources',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap any source to open in full-screen WebView',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemCount: _newsSources.length,
              itemBuilder: (context, index) {
                final source = _newsSources[index];
                return _buildSourceCard(source);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard(NewsSource source) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _openNewsSource(source),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: source.color.withValues(),
                  shape: BoxShape.circle,
                ),
                child: Icon(source.icon, color: source.color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                source.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              if (source.isLocal) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Local',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewsShimmer() {
    return Column(
      children: List.generate(5, (index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 100,
                        height: 12,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNewsFallback() {
    return Column(
      children: [
        Icon(Icons.wifi_off, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        const Text(
          'Could not load breaking news',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Text(
          'Check your internet connection',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _fetchBreakingNews(),
          icon: const Icon(Icons.refresh),
          label: const Text('Try Again'),
        ),
        const SizedBox(height: 20),
        const Text(
          'Quick News Links:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildQuickNewsLinks(),
      ],
    );
  }

  Widget _buildQuickNewsLinks() {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.open_in_new, size: 20),
          title: const Text('BBC Breaking News'),
          onTap: () => _launchURL('https://www.bbc.com/news'),
        ),
        ListTile(
          leading: const Icon(Icons.open_in_new, size: 20),
          title: const Text('Reuters Top News'),
          onTap: () => _launchURL('https://www.reuters.com/world/'),
        ),
        ListTile(
          leading: const Icon(Icons.open_in_new, size: 20),
          title: const Text('Al Jazeera Latest'),
          onTap: () => _launchURL('https://www.aljazeera.com/latest-news/'),
        ),
      ],
    );
  }

  Widget _buildNewsArticleCard(NewsArticle article, bool isTop) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isTop ? 3 : 1,
      color: isTop ? Colors.red.shade50 : null,
      child: InkWell(
        onTap: () => _openArticle(article),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade200,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: article.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: article.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade200,
                          ),
                          errorWidget: (context, url, error) => _buildPlaceholderIcon(),
                        )
                      : _buildPlaceholderIcon(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isTop)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'TOP STORY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (isTop) const SizedBox(height: 4),
                    Text(
                      article.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isTop ? FontWeight.bold : FontWeight.w500,
                        color: isTop ? Colors.red.shade800 : null,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatArticleDate(article.publishedAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (article.description.isNotEmpty)
                      Text(
                        article.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      article.source,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      color: Colors.grey.shade200,
      child: Icon(
        Icons.article,
        size: 32,
        color: Colors.grey.shade400,
      ),
    );
  }

  void _openNewsSource(NewsSource source) {
    _showInterstitialIfNeeded(); 
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewScreen(source: source),
      ),
    );
  }

  void _openArticle(NewsArticle article) {
    _showInterstitialIfNeeded();
    if (article.url.isNotEmpty) {
      _launchURL(article.url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Article link not available')),
      );
    }
  }

 Future<void> _launchURL(String url) async {
  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open: $e')),
      );
    }
  }
}

  String _formatArticleDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  void _showBreakingNewsInfo() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Breaking News Info',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'We fetch breaking news from trusted sources. '
                'All news is loaded directly from source websites - '
                'we don\'t store or modify any content.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              const Text(
                'Features:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildFeatureItem(Icons.refresh, 'Pull to refresh for latest news'),
              _buildFeatureItem(Icons.open_in_new, 'Tap any article to read full story'),
              _buildFeatureItem(Icons.web, 'WebView integration for full browsing'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
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

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      )
    );
  }
}

// WebView Screen for individual news sources
class WebViewScreen extends StatefulWidget {
  final NewsSource source;

  const WebViewScreen({super.key, required this.source});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
            setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.source.url));
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.source.name),
        backgroundColor: widget.source.color,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  Container(
                    color: Colors.white,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: widget.source.color),
                          const SizedBox(height: 16),
                          Text(
                            'Loading ${widget.source.name}...',
                            style: TextStyle(color: widget.source.color),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const AdBanner(),
        ],
      ),
    );
  }
}

// Model Classes
class NewsSource {
  final String name;
  final String url;
  final String rssUrl;
  final IconData icon;
  final Color color;
  final bool isLocal;

  NewsSource({
    required this.name,
    required this.url,
    required this.rssUrl,
    required this.icon,
    required this.color,
    this.isLocal = false,
  });
}

class NewsArticle {
  final String title;
  final String description;
  final String url;
  final String imageUrl;
  final String source;
  final String publishedAt;

  NewsArticle({
    required this.title,
    required this.description,
    required this.url,
    required this.imageUrl,
    required this.source,
    required this.publishedAt,
  });
}