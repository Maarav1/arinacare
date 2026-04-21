// lib/features/browser/presentation/widgets/tab_view.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:arina_cave/features/browser/presentation/controllers/web_tab_manager.dart';

class TabView extends StatefulWidget {
  final WebTabController controller;
  final String? initialUrl;
  
  const TabView({
    super.key,
    required this.controller,
    this.initialUrl,
  });
  
  @override
  State<TabView> createState() => _TabViewState();
}

class _TabViewState extends State<TabView> {
  late WebViewController _webViewController;
  
  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }
  
  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (progress) {
          widget.controller.progress.value = progress / 100;
          widget.controller.isLoading.value = progress < 100;
        },
        onPageStarted: (url) {
          widget.controller.currentUrl.value = url;
          widget.controller.isLoading.value = true;
        },
        onPageFinished: (url) {
          widget.controller.currentUrl.value = url;
          widget.controller.isLoading.value = false;
          
          // Get page title
          _webViewController.getTitle().then((title) {
            widget.controller.pageTitle.value = title;
          });
        },
        onUrlChange: (change) {
          widget.controller.currentUrl.value = change.url;
        },
        onNavigationRequest: (request) {
          // Allow all navigation
          return NavigationDecision.navigate;
        },
      ));
    
    widget.controller.webViewController = _webViewController;
    
    // Load initial URL
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _webViewController.loadRequest(Uri.parse(widget.initialUrl!));
    } else {
      // Load default page
      _webViewController.loadRequest(Uri.parse('https://www.google.com'));
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _webViewController),
        
        // Progress indicator
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<double>(
            valueListenable: widget.controller.progress,
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
        ),
        
        // Loading overlay
        ValueListenableBuilder<bool>(
          valueListenable: widget.controller.isLoading,
          builder: (context, isLoading, child) {
            return isLoading
                ? Container(
                    color: Colors.black.withAlpha(50),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                : const SizedBox.shrink();
          },
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    super.dispose();
  }
}