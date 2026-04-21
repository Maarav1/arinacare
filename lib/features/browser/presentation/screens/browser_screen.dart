// lib/features/browser/presentation/screens/browser_screen.dart
import 'package:arina_cave/features/browser/presentation/screens/monetization_disclosure_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:arina_cave/features/browser/presentation/controllers/web_tab_manager.dart';
import 'package:arina_cave/features/browser/engagement/services/ad_service.dart';

class TabView extends StatelessWidget {
  final WebTabController controller;
  final String? initialUrl;
  
  const TabView({
    super.key,
    required this.controller,
    this.initialUrl,
  });
  
  @override
  Widget build(BuildContext context) {
    final adService = Provider.of<AdService>(context);
    
    return Stack(
      children: [
        WebViewWidget(
          controller: WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setBackgroundColor(Colors.black)
            ..setNavigationDelegate(NavigationDelegate(
              onProgress: (progress) {
                controller.progress.value = progress / 100;
              },
              onPageStarted: (url) {
                controller.currentUrl.value = url;
                adService.showInterstitialAd();
              },
              onPageFinished: (url) {
                controller.currentUrl.value = url;
                // Get page title
                controller.webViewController?.getTitle().then((title) {
                  controller.pageTitle.value = title;
                });
              },
              onUrlChange: (change) {
                controller.currentUrl.value = change.url;
              },
            ))
            ..loadRequest(Uri.parse(initialUrl ?? 'https://google.com')),
        ),
        
        // Progress indicator
        ValueListenableBuilder<double>(
          valueListenable: controller.progress,
          builder: (context, progress, child) {
            return progress < 1.0
                ? LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.transparent,
                    color: Colors.blue,
                  )
                : const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

class BrowserScreen extends StatefulWidget {
  final String? initialUrl;
  
  const BrowserScreen({
    super.key,
    this.initialUrl,
  });
  
  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late WebTabManager _tabManager;
  final _urlController = TextEditingController();
  final _focusNode = FocusNode();
  
  @override
  void initState() {
    super.initState();
    _tabManager = WebTabManager();
    _initializeBrowser();
  }
  
  Future<void> _initializeBrowser() async {
    await _tabManager.createTab(
      initialUrl: widget.initialUrl,
      incognito: false,
    );
  }
  
  void _loadUrl(String url) {
    final controller = _tabManager.activeController?.webViewController;
    if (controller == null) return;
    
    String finalUrl = url.trim();
    if (finalUrl.isEmpty) return;
    
    if (!finalUrl.contains('.') || finalUrl.contains(' ')) {
      // It's a search query
      finalUrl = 'https://www.google.com/search?q=${Uri.encodeComponent(finalUrl)}';
    } else if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }
    
    controller.loadRequest(Uri.parse(finalUrl));
  }
  
  @override
  Widget build(BuildContext context) {
    final adService = Provider.of<AdService>(context);
    final activeController = _tabManager.activeController;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Navigation bar
            _buildNavigationBar(activeController),
            
            // Content
            Expanded(
              child: activeController != null
                  ? TabView(
                      controller: activeController,
                      initialUrl: activeController.initialUrl,
                    )
                  : _buildNewTabPage(),
            ),
            
            // Bottom banner ad
            adService.buildBannerAd(height: 60),
          ],
        ),
      ),
      
      // Tab switcher FAB
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        onPressed: _showTabSwitcher,
        child: const Icon(Icons.tab),
      ),
    );
  }
  
  Widget _buildNavigationBar(WebTabController? controller) {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => controller?.webViewController?.goBack(),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward, color: Colors.white),
            onPressed: () => controller?.webViewController?.goForward(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => controller?.webViewController?.reload(),
          ),
          Expanded(
            child: Card(
              color: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: TextField(
                  controller: _urlController,
                  focusNode: _focusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Search or enter URL',
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                  onSubmitted: _loadUrl,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: _showBrowserMenu,
          ),
        ],
      ),
    );
  }
  
  Widget _buildNewTabPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Arina Cave Browser',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 300,
            child: TextField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                hintText: 'Search or enter address',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.blue),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.mic, color: Colors.blue),
                  onPressed: () {},
                ),
              ),
              onSubmitted: _loadUrl,
            ),
          ),
          const SizedBox(height: 30),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              _buildQuickLink('Google', Icons.search, 'https://google.com'),
              _buildQuickLink('YouTube', Icons.play_arrow, 'https://youtube.com'),
              _buildQuickLink('Gmail', Icons.email, 'https://gmail.com'),
              _buildQuickLink('GitHub', Icons.code, 'https://github.com'),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickLink(String name, IconData icon, String url) {
    return GestureDetector(
      onTap: () => _loadUrl(url),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.blue[900],
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
  
  void _showTabSwitcher() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tabs',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ..._tabManager.tabs.map((tab) {
                return ListTile(
                  leading: const Icon(Icons.tab, color: Colors.white),
                  title: Text(
                    tab.pageTitle.value ?? 'New Tab',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    tab.currentUrl.value ?? 'about:blank',
                    style: TextStyle(color: Colors.grey[400]),
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => _tabManager.closeTab(tab),
                  ),
                  onTap: () {
                    _tabManager.setActiveController(tab);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _tabManager.createTab();
                  Navigator.pop(context);
                },
                child: const Text('New Tab'),
              ),
            ],
          ),
        );
      },
    );
  }
  
  void _showBrowserMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.white),
                title: const Text(
                  'Settings',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showSettings();
                },
              ),
              ListTile(
                leading: const Icon(Icons.info, color: Colors.white),
                title: const Text(
                  'Monetization Disclosure',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showMonetizationDisclosure();
                },
              ),
              ListTile(
                leading: const Icon(Icons.security, color: Colors.white),
                title: const Text(
                  'Privacy Policy',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Open privacy policy
                },
              ),
              ListTile(
                leading: const Icon(Icons.close, color: Colors.red),
                title: const Text(
                  'Close All Tabs',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  _tabManager.closeAllTabs();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
  
  void _showSettings() {
    // Implement settings screen
  }
  
  void _showMonetizationDisclosure() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MonetizationDisclosureScreen(),
      ),
    );
  }
  
  @override
  void dispose() {
    _tabManager.dispose();
    _urlController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}