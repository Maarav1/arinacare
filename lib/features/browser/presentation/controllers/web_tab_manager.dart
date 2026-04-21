// lib/features/browser/presentation/controllers/web_tab_manager.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:hive/hive.dart';
import 'package:arina_cave/features/browser/domain/models/browser_tab.dart';

class WebTabController {
  final String id;
  final String? initialUrl;
  final bool isIncognito;
  
  WebViewController? webViewController;
  ValueNotifier<double> progress = ValueNotifier(0.0);
  ValueNotifier<String?> currentUrl = ValueNotifier(null);
  ValueNotifier<String?> pageTitle = ValueNotifier(null);
  ValueNotifier<bool> isLoading = ValueNotifier(false);
  
  WebTabController({
    required this.id,
    this.initialUrl,
    this.isIncognito = false,
  });
  
  void dispose() {
    progress.dispose();
    currentUrl.dispose();
    pageTitle.dispose();
    isLoading.dispose();
  }
}

class WebTabManager with ChangeNotifier {
  final List<WebTabController> _tabs = [];
  WebTabController? _activeController;
  
  List<WebTabController> get tabs => List.unmodifiable(_tabs);
  WebTabController? get activeController => _activeController;
  
  int get tabCount => _tabs.length;
  
  Future<WebTabController> createTab({
    String? initialUrl,
    bool incognito = false,
  }) async {
    final tab = WebTabController(
      id: 'tab_${DateTime.now().microsecondsSinceEpoch}',
      initialUrl: initialUrl,
      isIncognito: incognito,
    );
    
    _tabs.add(tab);
    _activeController = tab;
    
    // Save to Hive
    await _saveTabToStorage(tab);
    
    notifyListeners();
    return tab;
  }
  
  Future<void> _saveTabToStorage(WebTabController tab) async {
    final box = Hive.box<BrowserTab>('browser_tabs');
    
    final hiveTab = BrowserTab(
      id: tab.id,
      initialUrl: tab.initialUrl,
      isIncognito: tab.isIncognito,
    );
    
    await box.put(tab.id, hiveTab);
  }
  
  void setActiveController(WebTabController controller) {
    if (_tabs.contains(controller)) {
      _activeController = controller;
      notifyListeners();
    }
  }
  
  Future<void> closeTab(WebTabController controller) async {
    controller.dispose();
    _tabs.remove(controller);
    
    if (_activeController == controller) {
      _activeController = _tabs.isNotEmpty ? _tabs.last : null;
    }
    
    // Remove from storage
    final box = Hive.box<BrowserTab>('browser_tabs');
    await box.delete(controller.id);
    
    notifyListeners();
  }
  
  Future<void> closeAllTabs() async {
    for (final tab in _tabs) {
      tab.dispose();
    }
    _tabs.clear();
    _activeController = null;
    
    final box = Hive.box<BrowserTab>('browser_tabs');
    await box.clear();
    
    notifyListeners();
  }
  
  Future<void> restoreTabsFromStorage() async {
    final box = Hive.box<BrowserTab>('browser_tabs');
    final savedTabs = box.values.toList();
    
    for (final savedTab in savedTabs) {
      final tab = WebTabController(
        id: savedTab.id,
        initialUrl: savedTab.initialUrl,
        isIncognito: savedTab.isIncognito,
      );
      
      _tabs.add(tab);
    }
    
    if (_tabs.isNotEmpty && _activeController == null) {
      _activeController = _tabs.last;
    }
    
    notifyListeners();
  }
  
  @override  // Add this annotation
  void dispose() {
    for (final tab in _tabs) {
      tab.dispose();
    }
    _tabs.clear();
    _activeController = null;
    super.dispose();
  }
}