import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// flutter_adsense is web-only; guard it so mobile builds don't break.
// ignore: avoid_web_libraries_in_flutter
import 'adsense_stub.dart' if (dart.library.js_interop) 'adsense_real.dart';

import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:arina_cave/hive_models.dart';

class AIScreen extends StatefulWidget {
  const AIScreen({super.key});

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  late final WebViewController _controller;
  bool _isLoading = false;
  bool _showPlatformSelection = true;
  bool _usingGeminiAPI = false;
  FocusNode? _inputFocusNode;

  late BannerAd _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isBannerAdLoaded = false;
  bool _isInterstitialAdLoaded = false;
  Timer? _interstitialTimer;

  late Box<ChatMessageHive> _chatBox;
  late Box<ConversationHive> _conversationBox;
  late Box<UserProfileHive> _userProfileBox;

  String _geminiApiKey = '';
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _geminiInitialized = false;
  bool _isSendingMessage = false;

  bool _enableThinking = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _interestsController = TextEditingController();
  final ValueNotifier<bool> _hasTextOrImages = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isSendingNotifier = ValueNotifier<bool>(false);

  final ValueNotifier<int> _profileVersion = ValueNotifier<int>(0);

  String _currentTopic = '';

  // Input box expansion state (single line by default).
  bool _inputExpanded = false;

  // Header rotation (instant, every 5 minutes).
  Timer? _headerRotateTimer;
  int _headerRotation = 0;
  static const int _headerChipCount = 11;

  bool _forceNewConversation = false;
  String? _activeConversationId;

  String _currentStreamText = '';
  StreamSubscription<String>? _streamSubscription;
  bool _isStreaming = false;
  late ScrollController _scrollController;
  bool _isHiveLoading = true;

  String _lastIncompleteResponse = '';
  bool _isContinuingResponse = false;

  int _retryCount = 0;
  static const int _maxRetries = 5;
  String? _lastFailedPrompt;
  List<Uint8List>? _lastFailedImages;
  bool _hasPartialResponse = false;
  String _partialResponseOnError = '';

  String _selectedModel = 'gemini-2.5-flash';
  final List<GeminiModel> _availableModels = [
    GeminiModel(
      id: 'gemini-2.5-flash',
      name: 'Gemini 2.5 Flash',
      description: 'Best price-performance',
      priority: 'Recommended',
      bestFor: 'Most applications',
      isRecommended: true,
    ),
    GeminiModel(
      id: 'gemini-2.5-flash-lite',
      name: 'Gemini 2.5 Flash-Lite',
      description: 'Fastest & cheapest',
      priority: 'Budget',
      bestFor: 'Simple tasks',
      isRecommended: false,
    ),
    GeminiModel(
      id: 'gemini-3.5-flash-lite',
      name: 'Gemini 3.5 flash-lite',
      description: 'Stable workhorse',
      priority: 'Balanced',
      bestFor: 'General use',
      isRecommended: false,
    ),
    GeminiModel(
      id: 'gemini-flash-latest',
      name: 'Gemini 3.8 Flash',
      description: 'Ultra-cheap tier',
      priority: 'Budget',
      bestFor: 'High volume',
      isRecommended: false,
    ),
  ];

  final List<GlobalKey> _messageKeys = [];

  final List<AIPlatform> _aiPlatforms = [
    AIPlatform(
      name: 'ChatGPT',
      url: 'https://chat.openai.com/',
      icon: Icons.smart_toy,
      color: Colors.green,
      description: 'OpenAI\'s conversational AI',
    ),
    AIPlatform(
      name: 'Gemini API',
      url: 'gemini://api',
      icon: Icons.auto_awesome,
      color: Colors.orange,
      description: 'Google\'s AI (Direct API)',
    ),
    AIPlatform(
      name: 'Gemini Web',
      url: 'https://gemini.google.com/',
      icon: Icons.language,
      color: Colors.blue,
      description: 'Google Gemini Web Version',
    ),
    AIPlatform(
      name: 'Claude',
      url: 'https://claude.ai/',
      icon: Icons.face,
      color: Colors.purple,
      description: 'Anthropic\'s Constitutional AI',
    ),
    AIPlatform(
      name: 'DeepSeek',
      url: 'https://chat.deepseek.com/',
      icon: Icons.psychology,
      color: Colors.blue,
      description: 'Free advanced AI model',
    ),
    AIPlatform(
      name: 'Blackbox',
      url: 'https://blackbox.ai/',
      icon: Icons.search,
      color: Colors.white,
      description: 'AI-powered search engine',
    ),
  ];

  final ImagePicker _picker = ImagePicker();
  final List<Uint8List> _selectedImages = [];

  final bool _enableAutoScroll = true;
  final bool _enableStreaming = true;
  final bool _enableImageUpload = true;
  final bool _enableHistory = true;
  double _temperature = 0.2;

  int _maxContextMessages = 100;
  bool _enableSmartContext = true;

  bool _alwaysSearchForAccuracy = true;

  final Stopwatch _thinkingStopwatch = Stopwatch();
  String _currentThinkingProcess = '';
  bool _isThinkingComplete = false;
  bool _isThinkingPhase = false;

  DateTime? _thinkingPhaseStartedAt;
  static const Duration _thinkingPhaseTimeout = Duration(seconds: 60);

  final bool _enableWebSearch = false;

  Timer? _autoScrollTimer;
  Timer? _scrollButtonTimer;
  bool _showScrollButton = false;
  bool _userScrolledUp = false;
  bool _isRetryCancelled = false;

  // The index of the currently shown "active turn" for the header chip.
  // Updated as the user scrolls or when a new turn is added.
  int _currentVisibleTurn = 1;

  // Tracks the index of the current error bubble so retries replace it
  // in place instead of appending a new one.
  int? _activeErrorIndex;

  bool get _isMobile => !kIsWeb;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeHive();
    _initializeApiKey();
    _initializeWebView();
    _initializeFocusNode();

    if (_isMobile) {
      MobileAds.instance.initialize();
      _loadBannerAd();
      _loadInterstitialAd();
      _startInterstitialTimer();
    }

    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _messageController.addListener(_updateSendButtonState);

    // Rotate header chips INSTANTLY every 5 minutes (no animation).
    _headerRotateTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!mounted) return;
      setState(() {
        _headerRotation = (_headerRotation + 1) % _headerChipCount;
      });
    });
  }

  void _updateSendButtonState() {
    final hasText = _messageController.text.trim().isNotEmpty;
    final hasImages = _selectedImages.isNotEmpty;
    _hasTextOrImages.value = hasText || hasImages;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final isNearBottom =
        _scrollController.offset >=
        _scrollController.position.maxScrollExtent - 150;
    if (!isNearBottom) {
      if (!_showScrollButton) {
        setState(() {
          _showScrollButton = true;
          _userScrolledUp = true;
        });
        _resetScrollButtonTimer();
      }
    } else {
      if (_userScrolledUp) {
        setState(() {
          _userScrolledUp = false;
          _showScrollButton = false;
        });
      }
    }

    // Update the header topic based on which turn is currently visible
    // near the top of the list.
    _recalculateVisibleTurn();
  }

    /// Looks at the current scroll offset and figures out which user
  /// message (turn) is closest to the top. Updates _currentVisibleTurn
  /// so the header can show that turn's topic.
  void _recalculateVisibleTurn() {
    if (!_scrollController.hasClients) return;
    if (_messages.isEmpty) {
      if (_currentVisibleTurn != 1) {
        setState(() => _currentVisibleTurn = 1);
      }
      return;
    }

    // Only consider the first few user messages per frame — we just
    // need to know which one is closest to the top of the viewport.
    int visibleTurn = 1;
    int userCount = 0;
    for (int i = 0; i < _messages.length; i++) {
      if (!_messages[i].isUser) continue;
      userCount++;
      if (i >= _messageKeys.length) continue;
      final ctx = _messageKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final pos = box.localToGlobal(Offset.zero);
      // The chat area begins roughly below the header (~34px) and the
      // AppBar (~56px). We use 60 as the threshold for "this turn is
      // now above the visible reading area".
      const topThreshold = 60.0;
      if (pos.dy < topThreshold) {
        visibleTurn = userCount;
      } else {
        break;
      }
    }
    if (visibleTurn != _currentVisibleTurn) {
      setState(() => _currentVisibleTurn = visibleTurn);
    }
  }

  /// Returns the topic for the Nth user turn, derived from the first 3
  /// words of that user's message, or falls back to _currentTopic for
  /// turn 1 if no message exists yet.
  String _topicForTurn(int turn) {
    if (turn < 1) turn = 1;
    int userCount = 0;
    for (final m in _messages) {
      if (!m.isUser) continue;
      userCount++;
      if (userCount == turn) {
        final words = m.text.trim().split(RegExp(r'\s+'));
        final take = words.length >= 3 ? 3 : words.length;
        return words.take(take).join(' ');
      }
    }
    return _currentTopic.isNotEmpty ? _currentTopic : 'Chat';
  }

  void _resetScrollButtonTimer() {
    _scrollButtonTimer?.cancel();
    _scrollButtonTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showScrollButton = false;
        });
      }
    });
  }

  void _initializeFocusNode() {
    _inputFocusNode = FocusNode();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _saveConversation();
    }
  }

  @override
  void dispose() {
    _cleanupResourcesSync();
    super.dispose();
  }

  void _cleanupResourcesSync() {
    _interstitialTimer?.cancel();
    _interstitialTimer = null;
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _scrollButtonTimer?.cancel();
    _scrollButtonTimer = null;
    _headerRotateTimer?.cancel();
    _headerRotateTimer = null;

    _streamSubscription?.cancel();
    _streamSubscription = null;

    _scrollController.removeListener(_onScroll);
    _messageController.removeListener(_updateSendButtonState);
    _messageController.dispose();
    _nameController.dispose();
    _interestsController.dispose();
    _inputFocusNode?.dispose();
    _scrollController.dispose();
    _hasTextOrImages.dispose();
    _isSendingNotifier.dispose();
    _profileVersion.dispose();

    if (_isMobile) {
      _bannerAd.dispose();
      _interstitialAd?.dispose();
    }
  }

  Future<void> _initializeHive() async {
    try {
      _chatBox = await Hive.openBox<ChatMessageHive>('chat_messages');
      _conversationBox = await Hive.openBox<ConversationHive>('conversations');
      _userProfileBox = await Hive.openBox<UserProfileHive>('user_profile');

      await _loadUserProfile();
      await _loadChatHistoryForModel(_selectedModel);

      if (mounted) {
        setState(() {
          _isHiveLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing Hive: $e');
      }
      if (mounted) {
        setState(() {
          _isHiveLoading = false;
        });
      }
    }
  }

  void _initializeApiKey() {
    _geminiApiKey = 'proxy';
    _geminiInitialized = true;
    if (kDebugMode) {
      print('✅ Gemini API using proxy (secure)');
    }
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

  Widget _buildBannerAd() {
    if (kIsWeb) return const SizedBox.shrink();
    if (!_isBannerAdLoaded) return const SizedBox.shrink();
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 8),
      child: AdWidget(ad: _bannerAd),
    );
  }

  Future<void> _pickImage() async {
    if (!_enableImageUpload) return;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (mounted) {
          setState(() {
            _selectedImages.add(bytes);
          });
        }
      }
    } catch (e) {
      if (kDebugMode) print('Image picker error: $e');
    }
  }

  Future<void> _removeImage(int index) async {
    if (mounted) {
      setState(() {
        _selectedImages.removeAt(index);
      });
    }
  }

  Future<void> _changeModel(String newModel) async {
    await _saveConversation();
    await _cancelCurrentStream();

    if (!mounted) return;

    setState(() {
      _selectedModel = newModel;
      _messages.clear();
      _messageKeys.clear();
      _activeErrorIndex = null;
      _currentStreamText = '';
      _selectedImages.clear();
      _currentThinkingProcess = '';
      _isThinkingComplete = false;
      _isThinkingPhase = false;
      _lastIncompleteResponse = '';
      _retryCount = 0;
      _lastFailedPrompt = null;
      _lastFailedImages = null;
      _hasPartialResponse = false;
      _partialResponseOnError = '';
      _activeConversationId = null;
      _currentTopic = '';
      _currentVisibleTurn = 1;
    });

    await _loadChatHistoryForModel(newModel);

    if (!mounted) return;
    final modelName = _availableModels.firstWhere((m) => m.id == newModel).name;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched to: $modelName'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getConversationPreview(String conversationId) {
    final messages =
        _chatBox.values
            .where((m) => m.conversationId == conversationId)
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final firstUserMessage =
        messages.where((m) => m.isUser).isNotEmpty
            ? messages.firstWhere((m) => m.isUser)
            : null;
    final text = firstUserMessage?.text.trim() ?? 'Untitled chat';
    if (text.length <= 80) return text;
    return '${text.substring(0, 80)}...';
  }

  Future<void> _deleteConversation(String conversationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Conversation'),
            content: const Text(
              'Are you sure you want to delete this conversation? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      final messagesToDelete =
          _chatBox.values
              .where((msg) => msg.conversationId == conversationId)
              .toList();
      for (final msg in messagesToDelete) {
        await msg.delete();
      }
      final conversationsToDelete =
          _conversationBox.values
              .where((conv) => conv.id == conversationId)
              .toList();
      for (final conv in conversationsToDelete) {
        await conv.delete();
      }
      if (_activeConversationId == conversationId) {
        setState(() {
          _messages.clear();
          _messageKeys.clear();
          _activeConversationId = null;
          _currentStreamText = '';
          _currentThinkingProcess = '';
          _isThinkingComplete = false;
          _isThinkingPhase = false;
          _currentVisibleTurn = 1;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversation deleted'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error deleting conversation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete conversation'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _loadChatHistoryForModel(String modelId) async {
    if (!_enableHistory) return;
    if (_isHiveLoading) return;

    try {
      final allConversations =
          _conversationBox.values
              .where((conv) => conv.modelUsed == modelId)
              .toList()
            ..sort(
              (a, b) =>
                  b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp),
            );

      final uniqueConversations = <String, ConversationHive>{};
      for (final conv in allConversations) {
        final preview = _getConversationPreview(conv.id);
        if (!uniqueConversations.containsKey(preview)) {
          uniqueConversations[preview] = conv;
        } else {
          final messagesToDelete =
              _chatBox.values
                  .where((msg) => msg.conversationId == conv.id)
                  .toList();
          for (final msg in messagesToDelete) {
            await msg.delete();
          }
          await conv.delete();
        }
      }

      final conversations =
          uniqueConversations.values.toList()..sort(
            (a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp),
          );

      if (conversations.isNotEmpty) {
        final latestConversation = conversations.first;
        final messages =
            _chatBox.values
                .where((msg) => msg.conversationId == latestConversation.id)
                .toList()
              ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

        if (mounted) {
          setState(() {
            _messages.clear();
            _messageKeys.clear();
            for (final msg in messages) {
              _messages.add(
                ChatMessage(
                  text: msg.text,
                  isUser: msg.isUser,
                  timestamp: msg.timestamp,
                  isLoading: false,
                  isError: msg.isError,
                  thinkingProcess: msg.thinkingProcess,
                  thinkingTime:
                      msg.thinkingTimeMs != null
                          ? Duration(milliseconds: msg.thinkingTimeMs!)
                          : null,
                  images: msg.imageBytes,
                  isIncomplete: msg.isIncomplete ?? false,
                ),
              );
              _messageKeys.add(GlobalKey());
            }
            _activeConversationId = latestConversation.id;
            _currentTopic = latestConversation.title ?? '';
            _currentVisibleTurn = 1;
          });

          final lastAiMsg = _messages.lastWhere(
            (m) => !m.isUser && m.isIncomplete && !m.isError,
            orElse:
                () => ChatMessage(
                  text: '',
                  isUser: false,
                  timestamp: DateTime.now(),
                ),
          );
          if (lastAiMsg.text.isNotEmpty) {
            _lastIncompleteResponse = lastAiMsg.text;
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _activeConversationId = null;
            _currentTopic = '';
            _currentVisibleTurn = 1;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading chat history for model $modelId: $e');
      }
    }
  }

  bool _isTimeSensitiveQuery(String query) {
    if (_alwaysSearchForAccuracy) return true;
    final keywords = [
      'today',
      'now',
      'current',
      'latest',
      'recent',
      'breaking',
      'news',
      '2024',
      '2025',
      '2026',
      'update',
      'happening now',
      'just happened',
      'this week',
      'this month',
      'this year',
    ];
    final lowerQuery = query.toLowerCase();
    return keywords.any((keyword) => lowerQuery.contains(keyword));
  }

  bool _checkIfResponseIncomplete(String response) {
    if (response.isEmpty) return false;
    final trimmedResponse = response.trim();
    if (trimmedResponse.contains('```') &&
        (trimmedResponse.split('```').length - 1) % 2 != 0) {
      return true;
    }
    final incompleteIndicators = [
      '...',
      '..',
      '--',
      '…',
      'etc.',
      'and',
      'but',
      'however',
      'therefore',
      'moreover',
      'furthermore',
      'in addition',
    ];
    final lastSentence = trimmedResponse.split('\n').last.toLowerCase();
    for (final indicator in incompleteIndicators) {
      if (lastSentence.endsWith(indicator.toLowerCase()) ||
          lastSentence.endsWith('${indicator.toLowerCase()}.')) {
        return true;
      }
    }
    final lines = trimmedResponse.split('\n');
    if (lines.isNotEmpty) {
      final lastLine = lines.last.trim();
      if ((lastLine.startsWith('- ') ||
              lastLine.startsWith('* ') ||
              lastLine.startsWith('+ ')) &&
          !lastLine.endsWith('.') &&
          !lastLine.endsWith('!') &&
          !lastLine.endsWith('?')) {
        return true;
      }
      if (RegExp(r'^\d+\.\s').hasMatch(lastLine) &&
          !lastLine.endsWith('.') &&
          !lastLine.endsWith('!') &&
          !lastLine.endsWith('?')) {
        return true;
      }
    }
    return false;
  }

  List<Map<String, dynamic>> _buildSmartContext(
    String currentPrompt,
    List<Uint8List>? currentImages,
  ) {
    final List<Map<String, dynamic>> contents = [];
    final userProfiles = _userProfileBox.values;
    final hasUserInfo = userProfiles.isNotEmpty;
    final userName = hasUserInfo ? userProfiles.first.name : '';
    final userInterests = hasUserInfo ? userProfiles.first.interests : '';

    final now = DateTime.now();
    final dateFormatter = DateFormat('MMMM dd, yyyy');
    final timeFormatter = DateFormat('HH:mm');
    final currentDate = dateFormatter.format(now);
    final currentTime = timeFormatter.format(now);
    final currentYear = now.year;

    String systemPrompt = '''You are a helpful AI assistant.

CRITICAL INSTRUCTIONS:
1. Answer the user's CURRENT/LATEST message as the main task
2. The previous messages are provided so you have real memory of this conversation
3. Do not pretend you have no memory of earlier turns in this same conversation
4. Do not repeat earlier turns back verbatim unless asked
5. Keep your response focused on what was JUST asked

Current Date: $currentDate
Current Time: $currentTime
Current Year: $currentYear''';

    if (hasUserInfo && userName.isNotEmpty) {
      systemPrompt += '\n\nUser\'s name: $userName';
      if (userInterests.isNotEmpty) {
        systemPrompt += '\nUser interests: $userInterests';
      }
    }

    systemPrompt += '''

DEEP REASONING (MANDATORY):
- Before you write anything, THINK deeply about the question.
- Review your draft internally for factual errors, typos, and logical mistakes. Fix them silently.
- Do NOT rush. Slow and correct beats fast and wrong.
- If unsure, say so. Never invent names, versions, dates, or citations.

TABLE FORMATTING:
- Use proper Markdown tables (| header | header | with separator |---|---|).
- NEVER use dots, ellipses, or placeholder text for a table.''';

    if (_alwaysSearchForAccuracy) {
      systemPrompt += '''

GROUNDING & ACCURACY (MANDATORY):
- You have Google Search grounding enabled. ALWAYS use it to verify any fact that could have changed over time.
- NEVER say "as of my knowledge cutoff", "I don't have information about X", "X does not exist", or "the latest is Y" without checking search results first.
- If the user names something you don't recognise, DO NOT claim it doesn't exist. Search first.
- If search and memory disagree, trust search.''';

      if (!_enableWebSearch) {
        systemPrompt +=
            '\n\nNote: For time-sensitive info, acknowledge your knowledge cutoff ONLY if search results are unavailable.';
      }
    } else {
      final isTimeSensitive = _isTimeSensitiveQuery(currentPrompt);
      if (isTimeSensitive && !_enableWebSearch) {
        systemPrompt +=
            '\n\nNote: For time-sensitive info, acknowledge your knowledge cutoff.';
      }
    }

    final bool isFirstTurn =
        _messages.where((m) => m.isUser).length <= 1 && _currentTopic.isEmpty;
    if (isFirstTurn) {
      systemPrompt += '''

At the very start of your reply, output a topic tag on its own line in this exact format: [TOPIC: up to 3 words]. Then continue with your normal reply on the next line.''';
    }

    if (_enableThinking) {
      systemPrompt +=
          '\n\nThinking format: "THINKING_START[your reasoning]THINKING_END" then provide final response.';
    }

    contents.add({
      'role': 'user',
      'parts': [
        {'text': systemPrompt},
      ],
    });

    contents.add({
      'role': 'model',
      'parts': [
        {
          'text':
              'Understood. I will use the full conversation history as real memory.${hasUserInfo && userName.isNotEmpty ? ' I know your name is $userName.' : ''} Current date: $currentDate.${_alwaysSearchForAccuracy ? ' I will verify with Google Search before answering.' : ''} I will think deeply and review my draft before responding.${_enableThinking ? ' I will use the thinking format.' : ''}',
        },
      ],
    });

    if (_messages.isNotEmpty) {
      final chatMessages =
          _messages
              .where(
                (msg) =>
                    !msg.text.contains('I understand') &&
                    !msg.text.contains('Understood'),
              )
              .toList();

      List<ChatMessage> contextMessages;
      if (chatMessages.length <= _maxContextMessages) {
        contextMessages = chatMessages;
      } else {
        contextMessages = [
          ...chatMessages.take(2),
          ...chatMessages.skip(chatMessages.length - (_maxContextMessages - 2)),
        ];
        contents.add({
          'role': 'user',
          'parts': [
            {'text': '[Earlier conversation history omitted for brevity]'},
          ],
        });
        contents.add({
          'role': 'model',
          'parts': [
            {'text': 'Noted. I\'ll keep that context in mind.'},
          ],
        });
      }

      for (final msg in contextMessages) {
        contents.add({
          'role': msg.isUser ? 'user' : 'model',
          'parts': [
            {'text': msg.text},
          ],
        });
      }
    }

    final List<Map<String, dynamic>> currentParts = [
      {'text': currentPrompt},
    ];

    if (currentImages != null && currentImages.isNotEmpty) {
      String mimeType = 'image/jpeg';
      if (currentImages.isNotEmpty && currentImages[0].length > 8) {
        final firstBytes = currentImages[0].sublist(0, 8);
        if (firstBytes[0] == 0x89 &&
            firstBytes[1] == 0x50 &&
            firstBytes[2] == 0x4E &&
            firstBytes[3] == 0x47) {
          mimeType = 'image/png';
        } else if (firstBytes[0] == 0x47 &&
            firstBytes[1] == 0x49 &&
            firstBytes[2] == 0x46) {
          mimeType = 'image/gif';
        } else if (firstBytes[0] == 0x52 &&
            firstBytes[1] == 0x49 &&
            firstBytes[2] == 0x46 &&
            firstBytes[3] == 0x46) {
          mimeType = 'image/webp';
        } else if (firstBytes[0] == 0x42 && firstBytes[1] == 0x4D) {
          mimeType = 'image/bmp';
        }
      }
      for (var imageBytes in currentImages) {
        currentParts.add({
          'inline_data': {
            'mime_type': mimeType,
            'data': base64Encode(imageBytes),
          },
        });
      }
    }

    contents.add({'role': 'user', 'parts': currentParts});
    return contents;
  }

  String _stripTopicTag(String text) {
    return text.replaceFirst(RegExp(r'^\s*\[TOPIC:[^\]]*\]\s*\n?'), '');
  }

  Stream<String> _streamGeminiResponse(
    String prompt, {
    List<Uint8List>? images,
  }) async* {
    final bool streamMode = _enableStreaming;
    final String url =
        'https://us-central1-lifematters-c466d.cloudfunctions.net/geminiProxy?model=$_selectedModel&streaming=true';

    final headers = {'Content-Type': 'application/json'};
    final contents = _buildSmartContext(prompt, images);

    final requestBody = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        'temperature': _temperature,
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 131072,
      },
      'safetySettings': [
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_ONLY_HIGH',
        },
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_ONLY_HIGH',
        },
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_ONLY_HIGH',
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_ONLY_HIGH',
        },
      ],
      'tools': [
        {'google_search': {}},
      ],
    };

    if (kDebugMode) {
      print('🔗 Sending request, streamMode=$streamMode');
      print('📝 Prompt: $prompt');
    }

    final request = http.Request('POST', Uri.parse(url));
    request.headers.addAll(headers);
    request.body = jsonEncode(requestBody);

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 90),
      onTimeout: () {
        throw Exception('Request timed out after 90 seconds');
      },
    );

    if (streamedResponse.statusCode != 200) {
      final errorBody = await streamedResponse.stream.bytesToString();
      throw Exception(
        'API request failed with status ${streamedResponse.statusCode}: $errorBody',
      );
    }

    String buffer = '';
    String fullBufferedText = '';

    await for (final chunk in streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (chunk.trim().isEmpty) continue;

      if (chunk.startsWith('data: ')) {
        final jsonString = chunk.substring(6);
        if (jsonString == '[DONE]') break;

        try {
          final jsonData = jsonDecode(jsonString);
          if (jsonData['candidates'] != null &&
              jsonData['candidates'].isNotEmpty) {
            final candidate = jsonData['candidates'][0];
            if (candidate['content'] != null &&
                candidate['content']['parts'] != null) {
              final parts = candidate['content']['parts'];
              if (parts.isNotEmpty && parts[0]['text'] != null) {
                final text = parts[0]['text'] as String;
                if (text.isNotEmpty) {
                  buffer += text;

                  if (_enableThinking &&
                      buffer.contains('THINKING_START') &&
                      !buffer.contains('THINKING_END')) {
                    final startedAt = _thinkingPhaseStartedAt ?? DateTime.now();
                    _thinkingPhaseStartedAt = startedAt;
                    final elapsed = DateTime.now().difference(startedAt);
                    if (elapsed < _thinkingPhaseTimeout) {
                      continue;
                    }
                  }

                  if (streamMode) {
                    // Drip the buffer out in small chunks so the user
                    // sees a "typing" effect rather than a pop.
                    final drip = buffer;
                    buffer = '';
                    // Break into small pieces and yield them with a
                    // small delay between each.
                    const chunkSize = 56;
                    for (int i = 0; i < drip.length; i += chunkSize) {
                      final end = (i + chunkSize).clamp(0, drip.length);
                      yield drip.substring(i, end);
                      await Future.delayed(const Duration(milliseconds: 1));
                    }
                  } else {
                    fullBufferedText += buffer;
                    buffer = '';
                  }
                }
              }
            }
          }
        } catch (e) {
          if (kDebugMode) print('⚠️ JSON parsing error: $e');
        }
      }
    }

    if (!streamMode) yield fullBufferedText;
  }

  /// Retry replaces the previous error bubble in place. No stacking.
  Future<void> _retryFailedRequest() async {
    _isRetryCancelled = false;
    if (_lastFailedPrompt == null) {
      final lastUser = _messages.lastWhere(
        (m) => m.isUser,
        orElse:
            () =>
                ChatMessage(text: '', isUser: true, timestamp: DateTime.now()),
      );
      if (lastUser.text.isNotEmpty) {
        _lastFailedPrompt = lastUser.text;
        _lastFailedImages = lastUser.images;
      } else {
        return;
      }
    }
    if (_retryCount >= _maxRetries) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum retry attempts reached'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    _retryCount++;

    // Remove the existing error bubble if we have one.
    if (mounted) {
      setState(() {
        if (_activeErrorIndex != null &&
            _activeErrorIndex! < _messages.length &&
            _messages[_activeErrorIndex!].isError) {
          _messages.removeAt(_activeErrorIndex!);
          if (_activeErrorIndex! < _messageKeys.length) {
            _messageKeys.removeAt(_activeErrorIndex!);
          }
          _activeErrorIndex = null;
        }
      });
    }

    await _sendGeminiMessageInternal(
      _lastFailedPrompt!,
      images: _lastFailedImages,
      isRetry: true,
    );
  }

  void _cancelRetry() {
    _isRetryCancelled = true;
    _cancelCurrentStream();
    if (mounted) {
      setState(() {
        _isSendingMessage = false;
        _isSendingNotifier.value = false;
        _isStreaming = false;
        _currentStreamText = '';
        if (_activeErrorIndex != null &&
            _activeErrorIndex! < _messages.length) {
          _messages[_activeErrorIndex!] = ChatMessage(
            text: '⚠️ Cancelled. Please try again.',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          );
        } else {
          _messages.add(
            ChatMessage(
              text: '⚠️ Cancelled. Please try again.',
              isUser: false,
              timestamp: DateTime.now(),
              isError: true,
            ),
          );
          _messageKeys.add(GlobalKey());
          _activeErrorIndex = _messages.length - 1;
        }
      });
    }
  }

  Future<void> _continueIncompleteResponse() async {
    if (_lastIncompleteResponse.isEmpty) {
      final lastIncomplete = _messages.lastWhere(
        (m) => !m.isUser && m.isIncomplete && !m.isError,
        orElse:
            () =>
                ChatMessage(text: '', isUser: false, timestamp: DateTime.now()),
      );
      if (lastIncomplete.text.isNotEmpty) {
        _lastIncompleteResponse = lastIncomplete.text;
      }
    }
    if (_isContinuingResponse || _lastIncompleteResponse.isEmpty) return;

    List<Uint8List>? carryImages;
    if (_messages.isNotEmpty) {
      final lastUser = _messages.lastWhere(
        (m) => m.isUser,
        orElse:
            () =>
                ChatMessage(text: '', isUser: true, timestamp: DateTime.now()),
      );
      if (lastUser.images != null && lastUser.images!.isNotEmpty) {
        carryImages = lastUser.images;
      }
    }

    setState(() {
      _isContinuingResponse = true;
      _isSendingMessage = true;
      _isStreaming = true;
      _currentThinkingProcess = '';
      _isThinkingComplete = false;
      _isThinkingPhase = false;
      _currentStreamText = '';
    });

    final String incompleteSnapshot = _lastIncompleteResponse;

    try {
      String accumulatedResponse = '';
      _streamSubscription = _streamGeminiResponse(
        "Continue your previous response from exactly where you stopped.",
        images: carryImages,
      ).listen(
        (chunk) {
          if (!mounted) return;
          setState(() {
            accumulatedResponse += chunk;
            _currentStreamText = _stripTopicTag(accumulatedResponse);
          });
          _scheduleAutoScroll();
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _messages.add(
              ChatMessage(
                text: 'Network error. Tap Retry.',
                isUser: false,
                timestamp: DateTime.now(),
                isError: true,
                canRetry: true,
              ),
            );
            _messageKeys.add(GlobalKey());
            _activeErrorIndex = _messages.length - 1;
            _resetContinueState();
          });
        },
        onDone: () async {
          if (!mounted) return;
          String continuation = accumulatedResponse;
          final overlapLen = _findOverlapLength(
            incompleteSnapshot,
            continuation,
          );
          if (overlapLen > 0) {
            continuation = continuation.substring(overlapLen);
          }
          final continuedResponse = incompleteSnapshot + continuation;

          setState(() {
            _messages.removeWhere((msg) => msg.text == incompleteSnapshot);
            _messages.add(
              ChatMessage(
                text: continuedResponse,
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
            _messageKeys.add(GlobalKey());
            _resetContinueState();
            _lastIncompleteResponse = '';
          });
          await _saveConversation();
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Network error. Tap Retry.',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
            canRetry: true,
          ),
        );
        _messageKeys.add(GlobalKey());
        _activeErrorIndex = _messages.length - 1;
        _resetContinueState();
      });
    }
  }

  int _findOverlapLength(String original, String continuation) {
    final int maxCheck = original.length < 400 ? original.length : 400;
    for (int len = maxCheck; len > 0; len--) {
      final suffix = original.substring(original.length - len);
      if (continuation.startsWith(suffix)) {
        return len;
      }
    }
    return 0;
  }

  void _resetContinueState() {
    _isContinuingResponse = false;
    _isSendingMessage = false;
    _isSendingNotifier.value = false;
    _isStreaming = false;
    _currentStreamText = '';
    _currentThinkingProcess = '';
    _isThinkingComplete = false;
    _isThinkingPhase = false;
  }

  _ParsedResponse _parseThinkingResponse(String fullResponse) {
    if (_enableThinking) {
      const thinkingStartMarker = 'THINKING_START';
      const thinkingEndMarker = 'THINKING_END';
      if (fullResponse.contains(thinkingStartMarker) &&
          fullResponse.contains(thinkingEndMarker)) {
        final thinkingBuffer = StringBuffer();
        int cursor = 0;
        while (true) {
          final start = fullResponse.indexOf(thinkingStartMarker, cursor);
          if (start == -1) break;
          final end = fullResponse.indexOf(
            thinkingEndMarker,
            start + thinkingStartMarker.length,
          );
          if (end == -1) break;
          final chunk =
              fullResponse
                  .substring(start + thinkingStartMarker.length, end)
                  .trim();
          if (chunk.isNotEmpty) {
            if (thinkingBuffer.isNotEmpty) thinkingBuffer.write('\n\n');
            thinkingBuffer.write(chunk);
          }
          cursor = end + thinkingEndMarker.length;
        }
        final cleaned =
            fullResponse
                .replaceAll(thinkingStartMarker, '')
                .replaceAll(thinkingEndMarker, '')
                .trim();
        if (thinkingBuffer.isNotEmpty) {
          return _ParsedResponse(
            thinkingProcess: thinkingBuffer.toString(),
            finalResponse: cleaned,
          );
        }
      }
    }
    return _ParsedResponse(thinkingProcess: '', finalResponse: fullResponse);
  }

  String _thinkingPhaseLabel(String thinkingTextSoFar) {
    final length = thinkingTextSoFar.trim().length;
    if (length == 0) return '🧠 Thinking...';
    if (length < 40) return '🔍 Sleuthing through the data...';
    if (length < 80) return '🧠 Cogitating on your question...';
    if (length < 120) return '🔎 Figuring out the best response...';
    if (length < 160) return '📊 Analyzing the context...';
    if (length < 200) return '🤔 Contemplating the nuances...';
    if (length < 240) return '🧩 Piecing together the answer...';
    if (length < 280) return '📝 Formulating a response...';
    if (length < 320) return '🔬 Examining the details...';
    if (length < 360) return '🧠 Processing your request...';
    if (length < 400) return '⚡ Running the reasoning...';
    if (length < 440) return '🌀 Fathoming the deeper meaning...';
    if (length < 480) return '🤔 Musing over the possibilities...';
    if (length < 520) return '📐 Triangulating the best approach...';
    if (length < 560) return '⚡ Honing the response...';
    if (length < 600) return '🎯 Mulling over the final details...';
    if (length < 640) return '🖼️ Picturing the complete answer...';
    if (length < 680) return '🔀 Untangling the complexity...';
    if (length < 720) return '🔍 Sifting through the reasoning...';
    if (length < 760) return '📊 Reckoning with the evidence...';
    if (length < 800) return '💡 Connecting the final dots...';
    return '✨ Finalizing the answer...';
  }

  Future<ConversationHive> _resolveCurrentConversation() async {
    if (_forceNewConversation || _activeConversationId == null) {
      final conversationId =
          '${DateTime.now().millisecondsSinceEpoch}_${_conversationBox.length}';
      final conversation =
          ConversationHive()
            ..id = conversationId
            ..lastMessageTimestamp = DateTime.now()
            ..messageCount = _messages.length
            ..modelUsed = _selectedModel;
      if (_currentTopic.isNotEmpty) {
        conversation.title = _currentTopic;
      }
      await _conversationBox.add(conversation);
      _forceNewConversation = false;
      _activeConversationId = conversationId;
      return conversation;
    }

    final existing = _conversationBox.values.firstWhere(
      (c) => c.id == _activeConversationId,
      orElse:
          () =>
              ConversationHive()
                ..id = _activeConversationId!
                ..lastMessageTimestamp = DateTime.now()
                ..messageCount = 0
                ..modelUsed = _selectedModel,
    );
    if (_currentTopic.isNotEmpty) {
      existing.title = _currentTopic;
    }
    if (!_conversationBox.values.any((c) => c.id == _activeConversationId)) {
      await _conversationBox.add(existing);
    }
    return existing;
  }

  Future<void> _saveConversation() async {
    if (!_enableHistory || _messages.isEmpty) return;
    if (_isHiveLoading) return;
    try {
      final currentConversation = await _resolveCurrentConversation();
      currentConversation.lastMessageTimestamp = DateTime.now();
      currentConversation.messageCount = _messages.length;
      if (_currentTopic.isNotEmpty) {
        currentConversation.title = _currentTopic;
      }
      await currentConversation.save();

      final finalConversationId = currentConversation.id;
      final oldMessages =
          _chatBox.values
              .where((msg) => msg.conversationId == finalConversationId)
              .toList();
      for (final msg in oldMessages) {
        await msg.delete();
      }

      for (final message in _messages) {
        final chatMsg = ChatMessageHive(
          text: message.text,
          isUser: message.isUser,
          timestamp: message.timestamp,
          isError: message.isError,
          modelUsed: _selectedModel,
          conversationId: finalConversationId,
          thinkingProcess: message.thinkingProcess,
          thinkingTimeMs: message.thinkingTime?.inMilliseconds,
          imageBytes: message.images,
          isIncomplete: message.isIncomplete,
        );
        await _chatBox.add(chatMsg);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving conversation: $e');
      }
    }
  }

  Future<void> _startNewChat() async {
    await _cancelCurrentStream();
    await _saveConversation();
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _messageKeys.clear();
      _activeErrorIndex = null;
      _currentStreamText = '';
      _selectedImages.clear();
      _currentThinkingProcess = '';
      _isThinkingComplete = false;
      _isThinkingPhase = false;
      _lastIncompleteResponse = '';
      _retryCount = 0;
      _lastFailedPrompt = null;
      _lastFailedImages = null;
      _hasPartialResponse = false;
      _partialResponseOnError = '';
      _forceNewConversation = true;
      _activeConversationId = null;
      _currentTopic = '';
      _currentVisibleTurn = 1;
      _inputExpanded = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Started a new chat'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadSpecificConversation(String conversationId) async {
    await _cancelCurrentStream();
    await _saveConversation();
    try {
      final messages =
          _chatBox.values
              .where((msg) => msg.conversationId == conversationId)
              .toList()
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (!mounted) return;

      final conv = _conversationBox.values.firstWhere(
        (c) => c.id == conversationId,
        orElse: () => ConversationHive()..id = conversationId,
      );

      setState(() {
        _messages.clear();
        _messageKeys.clear();
        _activeErrorIndex = null;
        for (final msg in messages) {
          _messages.add(
            ChatMessage(
              text: msg.text,
              isUser: msg.isUser,
              timestamp: msg.timestamp,
              isLoading: false,
              isError: msg.isError,
              thinkingProcess: msg.thinkingProcess,
              thinkingTime:
                  msg.thinkingTimeMs != null
                      ? Duration(milliseconds: msg.thinkingTimeMs!)
                      : null,
              images: msg.imageBytes,
              isIncomplete: msg.isIncomplete ?? false,
            ),
          );
          _messageKeys.add(GlobalKey());
        }
        _forceNewConversation = false;
        _activeConversationId = conversationId;
        _userScrolledUp = false;
        _showScrollButton = false;
        _currentTopic = conv.title ?? '';
        _currentVisibleTurn = 1;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    } catch (e) {
      if (kDebugMode) print('❌ Error loading specific conversation: $e');
    }
  }

  Future<void> _sendGeminiMessage() async {
    final String message = _messageController.text.trim();
    final List<Uint8List> images = List.from(_selectedImages);
    if (message.isEmpty && images.isEmpty) return;
    if (_isSendingMessage) return;

    _messageController.clear();
    if (_inputExpanded) {
      setState(() {
        _inputExpanded = false;
      });
    }

    if (mounted) {
      setState(() {
        _selectedImages.clear();
        _isSendingMessage = true;
        _isSendingNotifier.value = true;
        _updateSendButtonState();
      });
    }

    List<Uint8List>? compressedImages;
    if (images.isNotEmpty) {
      compressedImages = await _compressImages(images);
    }

    await _sendGeminiMessageInternal(
      message.isEmpty ? "[Image analysis request]" : message,
      images: compressedImages,
      isRetry: false,
    );
  }

  Future<void> _sendGeminiMessageInternal(
    String prompt, {
    List<Uint8List>? images,
    required bool isRetry,
  }) async {
    if (!isRetry) {
      _retryCount = 0;
      _lastFailedPrompt = prompt;
      _lastFailedImages = images;
      _hasPartialResponse = false;
      _partialResponseOnError = '';
      _isRetryCancelled = false;
    }

    await _cancelCurrentStream();

    if (mounted) {
      setState(() {
        _isStreaming = true;
        _currentThinkingProcess = '';
        _isThinkingComplete = false;
        _isThinkingPhase = false;
        _currentStreamText = '';
        _thinkingPhaseStartedAt = null;

        if (!isRetry) {
          _messages.add(
            ChatMessage(
              text: prompt,
              isUser: true,
              timestamp: DateTime.now(),
              images: images?.isNotEmpty == true ? List.from(images!) : null,
            ),
          );
          _messageKeys.add(GlobalKey());
          _activeErrorIndex = null;
          // New user turn -> bump visible turn.
          _currentVisibleTurn = _messages.where((m) => m.isUser).length;
        }
      });
    }

    _thinkingStopwatch.reset();
    _thinkingStopwatch.start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputFocusNode?.requestFocus();
    });

    _startAutoScrollTimer();

    try {
      String accumulatedResponse = '';
      bool thinkingDetected = false;

      _streamSubscription = _streamGeminiResponse(
        prompt,
        images: images,
      ).listen(
        (chunk) {
          try {
            if (!mounted) return;
            setState(() {
              accumulatedResponse += chunk;
              _partialResponseOnError = accumulatedResponse;
              _hasPartialResponse = true;

              if (_enableThinking) {
                if (!thinkingDetected &&
                    accumulatedResponse.contains('THINKING_START')) {
                  thinkingDetected = true;
                  _isThinkingPhase = true;
                  _thinkingPhaseStartedAt = DateTime.now();
                  final parsed = _parseThinkingResponse(accumulatedResponse);
                  if (parsed.thinkingProcess.isNotEmpty) {
                    _currentThinkingProcess = parsed.thinkingProcess;
                    _currentStreamText = '';
                  }
                } else if (thinkingDetected && !_isThinkingComplete) {
                  final parsed = _parseThinkingResponse(accumulatedResponse);
                  if (parsed.thinkingProcess.isNotEmpty) {
                    _currentThinkingProcess = parsed.thinkingProcess;
                  }
                  if (accumulatedResponse.contains('THINKING_END')) {
                    if (_thinkingStopwatch.isRunning) _thinkingStopwatch.stop();
                    _isThinkingComplete = true;
                    _isThinkingPhase = false;
                    _currentStreamText = _stripTopicTag(parsed.finalResponse);
                  }
                } else if (_isThinkingComplete) {
                  final parsed = _parseThinkingResponse(accumulatedResponse);
                  _currentStreamText = _stripTopicTag(parsed.finalResponse);
                }
              } else {
                _currentStreamText = _stripTopicTag(accumulatedResponse);
              }
            });
            _scheduleAutoScroll();
          } catch (e) {
            if (kDebugMode) print('⚠️ Stream chunk error: $e');
          }
        },
        onError: (error) async {
          if (!mounted) return;
          if (_isRetryCancelled) {
            setState(() {
              _resetMessageState();
              _isRetryCancelled = false;
            });
            return;
          }
          final errorMessage = error.toString();
          final isQuotaError =
              errorMessage.contains('RESOURCE_EXHAUSTED') ||
              errorMessage.contains('quota') ||
              errorMessage.contains('rate limit') ||
              errorMessage.contains('429');

          final errorText =
              isQuotaError
                  ? '⚠️ API Quota Exceeded\n\n$errorMessage\n\nPlease wait and try again.'
                  : '❌ Error: $errorMessage\n\nTap Retry to try again.';

          if (mounted) {
            setState(() {
              if (_activeErrorIndex != null &&
                  _activeErrorIndex! < _messages.length &&
                  _messages[_activeErrorIndex!].isError) {
                _messages[_activeErrorIndex!] = ChatMessage(
                  text: errorText,
                  isUser: false,
                  timestamp: DateTime.now(),
                  isError: true,
                  canRetry: true,
                );
              } else {
                _messages.add(
                  ChatMessage(
                    text: errorText,
                    isUser: false,
                    timestamp: DateTime.now(),
                    isError: true,
                    canRetry: true,
                  ),
                );
                _messageKeys.add(GlobalKey());
                _activeErrorIndex = _messages.length - 1;
              }
              _isStreaming = false;
              _isSendingMessage = false;
              _isSendingNotifier.value = false;
              _resetMessageState();
            });
          }
        },
        onDone: () async {
          if (!mounted) return;
          final parsedResponse = _parseThinkingResponse(accumulatedResponse);
          final thinkingText =
              _currentThinkingProcess.isNotEmpty
                  ? _currentThinkingProcess
                  : (parsedResponse.thinkingProcess.isNotEmpty
                      ? parsedResponse.thinkingProcess
                      : null);

          String finalOutput =
              parsedResponse.finalResponse.isNotEmpty
                  ? parsedResponse.finalResponse
                  : _currentStreamText;

          finalOutput =
              finalOutput
                  .replaceAll('THINKING_START', '')
                  .replaceAll('THINKING_END', '')
                  .trim();

          final topicRegex = RegExp(r'^\s*\[TOPIC:\s*(.+?)\]\s*\n?');
          final topicMatch = topicRegex.firstMatch(finalOutput);
          if (topicMatch != null) {
            final rawTopic = topicMatch.group(1)?.trim() ?? '';
            if (rawTopic.isNotEmpty) {
              final words = rawTopic.split(RegExp(r'\s+'));
              final capped = words.take(3).join(' ');
              _currentTopic = capped;
            }
            finalOutput = finalOutput.replaceFirst(topicRegex, '').trimLeft();
          } else if (_currentTopic.isEmpty) {
            final firstUser = _messages.firstWhere(
              (m) => m.isUser && m.text.trim().isNotEmpty,
              orElse:
                  () => ChatMessage(
                    text: '',
                    isUser: true,
                    timestamp: DateTime.now(),
                  ),
            );
            if (firstUser.text.isNotEmpty) {
              final words = firstUser.text.trim().split(RegExp(r'\s+'));
              _currentTopic = words.take(3).join(' ');
            }
          }

          final bool seemsIncomplete = _checkIfResponseIncomplete(finalOutput);

          setState(() {
            // Success -> clear error marker.
            _activeErrorIndex = null;

            if (seemsIncomplete) {
              _lastIncompleteResponse = finalOutput;
              _messages.add(
                ChatMessage(
                  text: finalOutput,
                  isUser: false,
                  timestamp: DateTime.now(),
                  thinkingProcess: thinkingText,
                  thinkingTime:
                      thinkingText != null ? _thinkingStopwatch.elapsed : null,
                  isIncomplete: true,
                ),
              );
            } else {
              _messages.add(
                ChatMessage(
                  text: finalOutput,
                  isUser: false,
                  timestamp: DateTime.now(),
                  thinkingProcess: thinkingText,
                  thinkingTime:
                      thinkingText != null ? _thinkingStopwatch.elapsed : null,
                ),
              );
            }
            _messageKeys.add(GlobalKey());
            _resetMessageState();
            _retryCount = 0;
            _lastFailedPrompt = null;
            _lastFailedImages = null;
          });

          await _saveConversation();
          _scheduleAutoScroll();
        },
      );
    } catch (e) {
      if (!mounted) return;
      final partialText = _partialResponseOnError;
      final hasPartial = _hasPartialResponse && partialText.isNotEmpty;
      setState(() {
        if (hasPartial) {
          _messages.add(
            ChatMessage(
              text: partialText,
              isUser: false,
              timestamp: DateTime.now(),
              isIncomplete: true,
            ),
          );
          _messageKeys.add(GlobalKey());
        }
        final errorText =
            'Failed to get response: ${e.toString()}\n\n${_retryCount < _maxRetries ? "Tap Retry." : "Max retries reached."}';
        if (_activeErrorIndex != null &&
            _activeErrorIndex! < _messages.length &&
            _messages[_activeErrorIndex!].isError) {
          _messages[_activeErrorIndex!] = ChatMessage(
            text: errorText,
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
            canRetry: _retryCount < _maxRetries,
          );
        } else {
          _messages.add(
            ChatMessage(
              text: errorText,
              isUser: false,
              timestamp: DateTime.now(),
              isError: true,
              canRetry: _retryCount < _maxRetries,
            ),
          );
          _messageKeys.add(GlobalKey());
          _activeErrorIndex = _messages.length - 1;
        }
        _resetMessageState();
      });
    }
  }

  Future<List<Uint8List>> _compressImages(List<Uint8List> images) async {
    final List<Uint8List> compressed = [];
    for (var image in images) {
      try {
        final codec = await ui.instantiateImageCodec(image, targetWidth: 1024);
        final frame = await codec.getNextFrame();
        final byteData = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (byteData != null) {
          compressed.add(byteData.buffer.asUint8List());
        } else {
          compressed.add(image);
        }
      } catch (e) {
        if (kDebugMode) print('⚠️ Image compression error: $e');
        compressed.add(image);
      }
    }
    return compressed;
  }

  void _resetMessageState() {
    _isSendingMessage = false;
    _isSendingNotifier.value = false;
    _isStreaming = false;
    _currentStreamText = '';
    _currentThinkingProcess = '';
    _isThinkingComplete = false;
    _isThinkingPhase = false;
    _thinkingPhaseStartedAt = null;
    _thinkingStopwatch.reset();
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _startAutoScrollTimer() {
    _autoScrollTimer?.cancel();
    if (_enableAutoScroll) {
      _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
        _scheduleAutoScroll();
      });
    }
  }

  void _scheduleAutoScroll() {
    if (!_enableAutoScroll || _userScrolledUp) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        try {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        } catch (e) {
          // Ignore scroll errors
        }
      }
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    void jumpOnce() {
      if (!mounted || !_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.animateTo(
        max,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    }

    jumpOnce();
    Future.delayed(const Duration(milliseconds: 150), jumpOnce);
    Future.delayed(const Duration(milliseconds: 350), jumpOnce);
    setState(() {
      _showScrollButton = false;
      _userScrolledUp = false;
    });
  }

  Widget _buildScrollToBottomButton() {
    if (!_showScrollButton) return const SizedBox.shrink();
    return Positioned(
      bottom: 80,
      left: 12,
      child: GestureDetector(
        onTap: _scrollToBottom,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(100),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_downward,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Future<void> _loadUserProfile() async {
    try {
      final profiles = _userProfileBox.values.toList();
      if (profiles.isNotEmpty) {
        final profile = profiles.first;
        _nameController.text = profile.name;
        _interestsController.text = profile.interests;
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error loading user profile: $e');
    }
  }

  Future<void> _saveUserProfile() async {
    try {
      await _userProfileBox.clear();
      final profile =
          UserProfileHive()
            ..name = _nameController.text.trim()
            ..interests = _interestsController.text.trim()
            ..createdAt = DateTime.now()
            ..updatedAt = DateTime.now();
      await _userProfileBox.add(profile);
      _profileVersion.value = _profileVersion.value + 1;
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error saving user profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save profile'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _cancelCurrentStream() async {
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    _thinkingStopwatch.reset();
    _currentThinkingProcess = '';
    _isThinkingComplete = false;
    _isThinkingPhase = false;
    _thinkingPhaseStartedAt = null;
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    if (_isSendingMessage && mounted) {
      setState(() {
        _isSendingMessage = false;
        _isSendingNotifier.value = false;
      });
    }
  }

  void _stopGenerating() {
    _cancelCurrentStream();
    if (mounted) {
      setState(() {
        _isStreaming = false;
        _isSendingMessage = false;
        _isSendingNotifier.value = false;
        _currentStreamText = '';
        _currentThinkingProcess = '';
        _isThinkingComplete = false;
        _isThinkingPhase = false;
      });
    }
  }

  Future<void> _showPlatformSelectionScreen() async {
    await _cancelCurrentStream();
    await _saveConversation();
    if (mounted) {
      setState(() {
        _showPlatformSelection = true;
        _usingGeminiAPI = false;
        _currentStreamText = '';
        _isStreaming = false;
        _selectedImages.clear();
        _currentThinkingProcess = '';
        _isThinkingComplete = false;
        _isThinkingPhase = false;
        _lastIncompleteResponse = '';
        _retryCount = 0;
        _lastFailedPrompt = null;
        _lastFailedImages = null;
        _activeErrorIndex = null;
      });
    }
  }

  void _openChatHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                _ChatHistoryScreen(buildHistory: _buildChatHistoryScreen),
        fullscreenDialog: true,
      ),
    );
  }

  Widget _buildChatHistoryScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Chat History'),
      ),
      body: FutureBuilder<List<ConversationHive>>(
        future: _loadUniqueConversations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          }
          final conversations = snapshot.data ?? const <ConversationHive>[];
          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, color: Colors.grey.shade700, size: 56),
                  const SizedBox(height: 12),
                  Text(
                    'No saved chats for this model yet',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final preview = _getConversationPreview(conversation.id);
              final title =
                  conversation.title?.isNotEmpty == true
                      ? conversation.title!
                      : preview;

              return Card(
                color: Colors.grey.shade900,
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueGrey,
                    radius: 17,
                    child: Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  title: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${conversation.messageCount} messages • ${DateFormat('MMM d, HH:mm').format(conversation.lastMessageTimestamp)}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        onPressed: () => _deleteConversation(conversation.id),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white38,
                        size: 14,
                      ),
                    ],
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _loadSpecificConversation(conversation.id);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<ConversationHive>> _loadUniqueConversations() async {
    final allConversations =
        _conversationBox.values
            .where((c) => c.modelUsed == _selectedModel)
            .toList()
          ..sort(
            (a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp),
          );

    final uniqueConversations = <String, ConversationHive>{};
    for (final conv in allConversations) {
      final preview = _getConversationPreview(conv.id);
      if (!uniqueConversations.containsKey(preview)) {
        uniqueConversations[preview] = conv;
      } else {
        final messagesToDelete =
            _chatBox.values
                .where((msg) => msg.conversationId == conv.id)
                .toList();
        for (final msg in messagesToDelete) {
          await msg.delete();
        }
        await conv.delete();
      }
    }

    return uniqueConversations.values.toList()..sort(
      (a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => StatefulBuilder(
            builder: (context, sheetSetState) {
              return Container(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '⚙️ Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildSettingsSection(
                        title: '🎯 Model & Thinking',
                        children: [
                          ListTile(
                            title: const Text(
                              'Model',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              _availableModels
                                  .firstWhere((m) => m.id == _selectedModel)
                                  .name,
                              style: const TextStyle(color: Colors.orange),
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white54,
                              size: 16,
                            ),
                            onTap: () => Navigator.pop(context),
                          ),
                          SwitchListTile(
                            title: const Text(
                              '🧠 Thinking Mode',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: const Text(
                              'Show step-by-step reasoning',
                              style: TextStyle(color: Colors.white54),
                            ),
                            value: _enableThinking,
                            activeColor: Colors.orange,
                            onChanged: (value) {
                              sheetSetState(() => _enableThinking = value);
                              if (mounted) {
                                setState(() => _enableThinking = value);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildSettingsSection(
                        title: '🌡️ Temperature Presets',
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      '🎯 Precise',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _temperature.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Text(
                                      ' 🎨 Creative',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                Slider(
                                  value: _temperature,
                                  min: 0.0,
                                  max: 1.0,
                                  divisions: 10,
                                  activeColor: Colors.orange,
                                  inactiveColor: Colors.grey.shade700,
                                  onChanged: (value) {
                                    sheetSetState(() => _temperature = value);
                                    if (mounted) {
                                      setState(() => _temperature = value);
                                    }
                                  },
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildPresetChip(
                                      'Precise',
                                      0.1,
                                      sheetSetState,
                                    ),
                                    _buildPresetChip(
                                      'Balanced',
                                      0.5,
                                      sheetSetState,
                                    ),
                                    _buildPresetChip(
                                      'Creative',
                                      0.8,
                                      sheetSetState,
                                    ),
                                    _buildPresetChip(
                                      'Wild',
                                      1.0,
                                      sheetSetState,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildSettingsSection(
                        title: '🌐 Accuracy',
                        children: [
                          SwitchListTile(
                            title: const Text(
                              'Always Search for Accuracy',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: const Text(
                              'Force Google Search grounding on every message.',
                              style: TextStyle(color: Colors.white54),
                            ),
                            value: _alwaysSearchForAccuracy,
                            activeColor: Colors.green,
                            onChanged: (value) {
                              sheetSetState(
                                () => _alwaysSearchForAccuracy = value,
                              );
                              if (mounted) {
                                setState(
                                  () => _alwaysSearchForAccuracy = value,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildSettingsSection(
                        title: 'Context Settings',
                        children: [
                          SwitchListTile(
                            title: const Text(
                              'Smart Context',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: const Text(
                              'Focus on recent messages',
                              style: TextStyle(color: Colors.white54),
                            ),
                            value: _enableSmartContext,
                            activeColor: Colors.green,
                            onChanged: (value) {
                              sheetSetState(() => _enableSmartContext = value);
                              if (mounted) {
                                setState(() => _enableSmartContext = value);
                              }
                            },
                          ),
                          ListTile(
                            title: const Text(
                              'Context Window Size',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              '$_maxContextMessages messages sent to the AI',
                              style: const TextStyle(color: Colors.white54),
                            ),
                            trailing: SizedBox(
                              width: 150,
                              child: Slider(
                                value: _maxContextMessages.toDouble(),
                                min: 5,
                                max: 100,
                                divisions: 19,
                                activeColor: Colors.green,
                                inactiveColor: Colors.grey.shade700,
                                onChanged: (value) {
                                  sheetSetState(
                                    () => _maxContextMessages = value.toInt(),
                                  );
                                  if (mounted) {
                                    setState(
                                      () => _maxContextMessages = value.toInt(),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade900,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Close',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  Widget _buildPresetChip(
    String label,
    double value,
    void Function(void Function()) sheetSetState,
  ) {
    final isActive = (_temperature - value).abs() < 0.05;
    return GestureDetector(
      onTap: () {
        sheetSetState(() => _temperature = value);
        if (mounted) setState(() => _temperature = value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? Colors.orange.withAlpha(50) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? Colors.orange : Colors.grey.shade700,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.orange : Colors.white54,
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  void _showProfileDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _buildUserProfileScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _loadUrl(String url) async {
    await _cancelCurrentStream();
    if (url == 'gemini://api') {
      if (!_geminiInitialized || _geminiApiKey != 'proxy') {
        _showApiErrorDialog();
        return;
      }
      if (mounted) {
        setState(() {
          _showPlatformSelection = false;
          _usingGeminiAPI = true;
          _selectedImages.clear();
          _currentThinkingProcess = '';
          _isThinkingComplete = false;
          _isThinkingPhase = false;
          _lastIncompleteResponse = '';
          _retryCount = 0;
          _lastFailedPrompt = null;
          _lastFailedImages = null;
          _activeErrorIndex = null;
          _updateSendButtonState();
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _showPlatformSelection = false;
          _usingGeminiAPI = false;
          _currentStreamText = '';
          _selectedImages.clear();
          _currentThinkingProcess = '';
          _isThinkingComplete = false;
          _isThinkingPhase = false;
          _lastIncompleteResponse = '';
          _isLoading = _isMobile;
          _updateSendButtonState();
        });
      }
      if (_isMobile) {
        await _controller.loadRequest(Uri.parse(url));
      }
    }
  }

  void _showApiErrorDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Gemini API Not Available'),
            content: const Text(
              'The Gemini API proxy is not available. Please check your internet connection or try again later.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showPlatformSelectionScreen();
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Widget _buildUserProfileScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Your Profile'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _saveUserProfile,
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.orange, fontSize: 16),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personalize Your AI Experience',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Help me get to know you better!',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            const Text(
              'Your Name',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'What should I call you?',
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade700),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.orange),
                ),
                filled: true,
                fillColor: Colors.grey.shade900,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your Interests',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _interestsController,
              style: const TextStyle(color: Colors.white),
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: 'What topics are you interested in?',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade700),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.orange),
                ),
                filled: true,
                fillColor: Colors.grey.shade900,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 50),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.lightGreen.withAlpha(100)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.orange, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This information is stored locally on your device. It is never sent to any external servers.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _initializeWebView() {
    if (kIsWeb) {
      _controller = WebViewController();
      return;
    }

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    controller.setBackgroundColor(const Color(0x00000000));

    controller.setNavigationDelegate(
      NavigationDelegate(
        onProgress: (int progress) {
          if (mounted) setState(() => _isLoading = progress < 100);
        },
        onPageStarted: (String url) {
          if (mounted) setState(() => _isLoading = true);
        },
        onPageFinished: (String url) {
          if (mounted) setState(() => _isLoading = false);
          _applyAccuracySettings(url);
        },
        onWebResourceError: (WebResourceError error) {
          if (mounted) setState(() => _isLoading = false);
          if (kDebugMode) print('WebView Error: ${error.description}');
        },
        onNavigationRequest: (NavigationRequest request) {
          return _shouldStayInWebView(request.url)
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
        onUrlChange: (UrlChange change) {
          if (kDebugMode) print('URL changed to: ${change.url}');
        },
      ),
    );

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller;
    _setUserAgent();
  }

  bool _shouldStayInWebView(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      const allowed = <String>[
        'chat.openai.com',
        'chatgpt.com',
        'gemini.google.com',
        'claude.ai',
        'chat.deepseek.com',
        'blackbox.ai',
        'google.com',
        'accounts.google.com',
        'appleid.apple.com',
        'login.microsoftonline.com',
        'openai.com',
        'anthropic.com',
        'deepseek.com',
      ];
      return allowed.any(
        (domain) => host == domain || host.endsWith('.$domain'),
      );
    } catch (_) {
      return true;
    }
  }

  void _applyAccuracySettings(String url) {
    if (kIsWeb) return;
    final jsCode = """
    (function() {
      function setAccuracySettings() {
        document.body.style.backgroundColor = '#000000';
        document.body.style.color = '#ffffff';
      }
      setAccuracySettings();
      if (!window.__accuracyObserverInstalled) {
        window.__accuracyObserverInstalled = true;
        const observer = new MutationObserver(setAccuracySettings);
        observer.observe(document.body, {
          childList: true,
          subtree: true,
          attributes: true,
        });
      }
    })();
  """;
    try {
      _controller.runJavaScript(jsCode);
    } catch (e) {
      if (kDebugMode) print('Failed to run JavaScript: $e');
    }
  }

  void _setUserAgent() async {
    if (kIsWeb) return;
    const desktopUserAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    try {
      await _controller.setUserAgent(desktopUserAgent);
    } catch (e) {
      if (kDebugMode) print('Failed to set user agent: $e');
    }
  }

  Widget _buildPlatformSelection() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Choose AI Platform'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Select an AI Platform',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
              ),
              itemCount: _aiPlatforms.length,
              itemBuilder: (context, index) {
                final platform = _aiPlatforms[index];
                return Card(
                  color: Colors.grey.shade900,
                  elevation: 4,
                  child: InkWell(
                    onTap: () => _loadUrl(platform.url),
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(platform.icon, size: 40, color: platform.color),
                        const SizedBox(height: 8),
                        Text(
                          platform.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (platform.name == 'Gemini API')
                          const Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            child: Text(
                              'API Mode',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        if (platform.name == 'Gemini Web')
                          const Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Web Version',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _buildBannerAd(),
        ],
      ),
    );
  }

  Widget _webCentered(Widget child) {
    if (!kIsWeb) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: child,
      ),
    );
  }

  /// Jump dialog with live suggestions.
  Future<void> _showJumpToTurnDialog() async {
    final controller = TextEditingController();
    final userTurns = <int, String>{};
    int turn = 0;
    for (final m in _messages) {
      if (m.isUser) {
        turn++;
        final preview =
            m.text.trim().length > 40
                ? '${m.text.trim().substring(0, 40)}...'
                : m.text.trim();
        userTurns[turn] = preview;
      }
    }

    if (userTurns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No turns yet'),
          backgroundColor: Colors.blueGrey,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            final query = controller.text.trim();
            final filtered = <int, String>{};
            if (query.isEmpty) {
              filtered.addAll(userTurns);
            } else {
              for (final entry in userTurns.entries) {
                if (entry.key.toString().startsWith(query) ||
                    entry.value.toLowerCase().contains(query.toLowerCase())) {
                  filtered[entry.key] = entry.value;
                }
              }
            }

            return AlertDialog(
              backgroundColor: Colors.grey.shade900,
              title: const Text(
                'Jump to turn',
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Type a number or keyword...',
                        hintStyle: TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.orange),
                        ),
                      ),
                      onChanged: (_) => dialogSetState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child:
                          filtered.isEmpty
                              ? const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'No matching turns',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              )
                              : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final entry = filtered.entries.elementAt(
                                    index,
                                  );
                                  return ListTile(
                                    dense: true,
                                    leading: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.lightBlue,
                                      child: Text(
                                        '${entry.key}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      entry.value,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                    onTap:
                                        () => Navigator.pop(context, entry.key),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;
    await _jumpToTurn(result);
  }

  Future<void> _jumpToTurn(int turnNumber) async {
    if (turnNumber < 1) return;
    int targetIndex = -1;
    int seen = 0;
    for (int i = 0; i < _messages.length; i++) {
      if (_messages[i].isUser) {
        seen++;
        if (seen == turnNumber) {
          targetIndex = i;
          break;
        }
      }
    }
    if (targetIndex < 0) return;

    _userScrolledUp = false;
    _showScrollButton = false;

    if (targetIndex < _messageKeys.length) {
      final key = _messageKeys[targetIndex];
      final ctx = key.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          alignment: 0.02,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
        if (!mounted) return;
        setState(() => _currentVisibleTurn = turnNumber);
        return;
      }
    }

    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final fraction = (targetIndex / (_messages.isEmpty ? 1 : _messages.length))
        .clamp(0.0, 1.0);
    await _scrollController.animateTo(
      max * fraction,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
    if (mounted) setState(() => _currentVisibleTurn = turnNumber);
  }

  Widget _buildHeaderChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The header strip. Chips rotate INSTANTLY every 5 minutes:
  /// the first chip disappears, everything shifts left, first goes
  /// to the end. No animation.
  Widget _buildHeaderStrip() {
    final modelName =
        _availableModels.firstWhere((m) => m.id == _selectedModel).name;
    final topicLabel = _topicForTurn(_currentVisibleTurn);

    // Order matters. Jump is between New and History.
    final chips = <Widget>[
      _buildHeaderChip(
        icon: Icons.model_training,
        label: modelName,
        color: Colors.orange,
        onTap: () {},
      ),
      _buildHeaderChip(
        icon: Icons.topic_outlined,
        label: topicLabel,
        color: Colors.amberAccent,
        onTap: () {},
      ),
      _buildHeaderChip(
        icon: _enableThinking ? Icons.psychology : Icons.flash_on,
        label: _enableThinking ? 'Thinking' : 'Fast',
        color: _enableThinking ? Colors.deepOrange : Colors.blue,
        onTap: () {
          setState(() => _enableThinking = !_enableThinking);
        },
      ),
      _buildHeaderChip(
        icon: Icons.thermostat,
        label: 'T:${_temperature.toStringAsFixed(1)}',
        color: Colors.lightBlue,
        onTap: () => _showSettings(),
      ),
      _buildHeaderChip(
        icon: Icons.memory,
        label: 'Ctx:$_maxContextMessages',
        color: Colors.green,
        onTap: () => _showSettings(),
      ),
      _buildHeaderChip(
        icon: Icons.add_comment_outlined,
        label: 'New',
        color: Colors.greenAccent,
        onTap: _startNewChat,
      ),
      _buildHeaderChip(
        icon: Icons.search,
        label: 'Jump',
        color: Colors.tealAccent,
        onTap: _showJumpToTurnDialog,
      ),
      _buildHeaderChip(
        icon: Icons.history,
        label: 'History',
        color: Colors.purpleAccent,
        onTap: _openChatHistory,
      ),
      _buildHeaderChip(
        icon: Icons.settings,
        label: 'Settings',
        color: Colors.brown,
        onTap: _showSettings,
      ),
      _buildHeaderChip(
        icon: Icons.person,
        label: 'Profile',
        color: Colors.lightGreen,
        onTap: _showProfileDialog,
      ),
      
    ];

    // Apply rotation: chips shifted left by _headerRotation.
    final rotated = <Widget>[];
    for (int i = 0; i < chips.length; i++) {
      rotated.add(chips[(_headerRotation + i) % chips.length]);
    }

    return Container(
      height: 34,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: Colors.grey.shade900,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        children: rotated,
      ),
    );
  }

  /// "Clear" chip — only clears the *current* conversation, not all
  /// history. So the user can't accidentally lose other chats.
  Future<void> _confirmClearCurrentChat() async {
    if (_messages.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear this chat?'),
            content: const Text(
              'This clears the current conversation only. Other saved chats remain untouched.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Clear', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    await _startNewChat();
  }

  Widget _buildGeminiAPIChat() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Gemini AI (API Mode)'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _showPlatformSelectionScreen,
        ),
        actions: [
          if (_isStreaming)
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.model_training, color: Colors.orange),
            tooltip: 'Change Model',
            itemBuilder: (context) {
              final currentModel = _availableModels.firstWhere(
                (m) => m.id == _selectedModel,
              );
              return [
                PopupMenuItem<String>(
                  value: 'header',
                  enabled: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CURRENTLY ACTIVE:',
                          style: TextStyle(
                            color: Colors.lightGreenAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentModel.name,
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          currentModel.description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                ..._availableModels.map((model) {
                  final isActive = _selectedModel == model.id;
                  return PopupMenuItem<String>(
                    value: model.id,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            isActive
                                ? Colors.orange.withAlpha(50)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isActive
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: isActive ? Colors.white : Colors.blue,
                            size: 16,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      model.name,
                                      style: TextStyle(
                                        color:
                                            isActive
                                                ? Colors.white
                                                : Colors.green,
                                        fontSize: 14,
                                        fontWeight:
                                            isActive
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (model.isRecommended)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                        child: const Text(
                                          'BEST',
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                Text(
                                  model.description,
                                  style: TextStyle(
                                    color:
                                        isActive
                                            ? Colors.white70
                                            : Colors.green,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'newchat',
                  child: ListTile(
                    leading: const Icon(
                      Icons.add_comment_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'New Chat',
                      style: TextStyle(color: Colors.greenAccent),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _startNewChat();
                    },
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'jump',
                  child: ListTile(
                    leading: const Icon(Icons.search, color: Colors.white),
                    title: const Text(
                      'Jump to turn',
                      style: TextStyle(color: Colors.tealAccent),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showJumpToTurnDialog();
                    },
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'history',
                  child: ListTile(
                    leading: const Icon(Icons.history, color: Colors.white),
                    title: const Text(
                      'Chat History',
                      style: TextStyle(color: Colors.blueAccent),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _openChatHistory();
                    },
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'settings',
                  child: ListTile(
                    leading: const Icon(Icons.settings, color: Colors.white),
                    title: const Text(
                      'Settings',
                      style: TextStyle(color: Colors.brown),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showSettings();
                    },
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'profile',
                  child: ListTile(
                    leading: const Icon(Icons.person, color: Colors.white),
                    title: const Text(
                      'Edit Profile',
                      style: TextStyle(color: Colors.green),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showProfileDialog();
                    },
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'clear',
                  child: ListTile(
                    leading: const Icon(Icons.delete, color: Colors.white),
                    title: const Text(
                      'Clear this chat',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _confirmClearCurrentChat();
                    },
                  ),
                ),
              ];
            },
            onSelected: (value) {
              if (value == 'settings') {
                _showSettings();
              } else if (value == 'profile') {
                _showProfileDialog();
              } else if (value == 'clear') {
                _confirmClearCurrentChat();
              } else if (value == 'newchat') {
                _startNewChat();
              } else if (value == 'jump') {
                _showJumpToTurnDialog();
              } else if (value == 'history') {
                _openChatHistory();
              } else if (_availableModels.any((m) => m.id == value)) {
                _changeModel(value);
              }
            },
          ),
        ],
      ),
      body: Row(
        children: [
          if (kIsWeb)
            Container(
              width: 280,
              color: Colors.grey.shade900,
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blueAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: const AdsenseWidget(
                        adClient: 'ca-pub-1472609237394607',
                        adSlot: '1318293971',
                        adFormat: 'auto',
                        fullWidthResponsive: true,
                        width: 280,
                        height: 250,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Support ArinaCave",
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Stack(
                children: [
                  _webCentered(
                    Column(
                      children: [
                        _buildHeaderStrip(),

                        Expanded(
                          child:
                              _messages.isEmpty && _currentStreamText.isEmpty
                                  ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.auto_awesome,
                                          size: 64,
                                          color: Colors.orange,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Welcome to ${_availableModels.firstWhere((m) => m.id == _selectedModel).name}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Smart Context: ${_enableSmartContext ? "ON" : "OFF"} | Window: $_maxContextMessages msgs',
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Temperature: ${_temperature.toStringAsFixed(1)} | Streaming: ${_enableStreaming ? "Enabled" : "Disabled"}',
                                          style: const TextStyle(
                                            color: Colors.blue,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        ValueListenableBuilder<int>(
                                          valueListenable: _profileVersion,
                                          builder: (context, _, __) {
                                            if (_userProfileBox
                                                .values
                                                .isEmpty) {
                                              return GestureDetector(
                                                onTap: _showProfileDialog,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green
                                                        .withAlpha(30),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.person_add,
                                                        color: Colors.green,
                                                        size: 16,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Set up your profile',
                                                        style: TextStyle(
                                                          color: Colors.green,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ],
                                    ),
                                  )
                                  : ListView.builder(
                                    controller: _scrollController,
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.only(
                                      top: 4,
                                      bottom: 100,
                                      left: 2,
                                      right: 2,
                                    ),
                                    itemCount:
                                        _messages.length +
                                        (_currentStreamText.isNotEmpty ||
                                                _isThinkingPhase ||
                                                (_isStreaming &&
                                                    _messages.isNotEmpty)
                                            ? 1
                                            : 0),
                                    itemBuilder: (context, index) {
                                      if (index < _messages.length) {
                                        int turnNumber = 0;
                                        for (int i = 0; i <= index; i++) {
                                          if (_messages[i].isUser) turnNumber++;
                                        }
                                        return ChatBubbleWithThinking(
                                          key:
                                              index < _messageKeys.length
                                                  ? _messageKeys[index]
                                                  : null,
                                          message: _messages[index],
                                          enableAutoScroll: _enableAutoScroll,
                                          turnNumber:
                                              _messages[index].isUser
                                                  ? turnNumber
                                                  : 0,
                                          onContinuePressed:
                                              _messages[index].isIncomplete
                                                  ? _continueIncompleteResponse
                                                  : null,
                                          onRetryPressed:
                                              _messages[index].canRetry
                                                  ? _retryFailedRequest
                                                  : null,
                                          onCancelPressed: _cancelRetry,
                                        );
                                      } else {
                                        if (_isThinkingPhase &&
                                            _enableThinking) {
                                          final phaseLabel =
                                              _thinkingPhaseLabel(
                                                _currentThinkingProcess,
                                              );
                                          return Container(
                                            margin: const EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 4,
                                            ),
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade900,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.purpleAccent
                                                    .withAlpha(60),
                                                width: 1,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.psychology,
                                                      color:
                                                          Colors.purpleAccent,
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    const Text(
                                                      'Thinking...',
                                                      style: TextStyle(
                                                        color:
                                                            Colors.purpleAccent,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    const SizedBox(
                                                      width: 14,
                                                      height: 14,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                              Color
                                                            >(
                                                              Colors
                                                                  .purpleAccent,
                                                            ),
                                                      ),
                                                    ),
                                                    const Spacer(),
                                                    Text(
                                                      phaseLabel,
                                                      style: const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 11,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (_currentThinkingProcess
                                                    .isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 10,
                                                        ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            12,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        _currentThinkingProcess,
                                                        style: const TextStyle(
                                                          color:
                                                              Colors
                                                                  .lightGreenAccent,
                                                          fontSize: 13,
                                                          height: 1.4,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          );
                                        } else {
                                          return ChatBubbleWithThinking(
                                            message: ChatMessage(
                                              text: _currentStreamText,
                                              isUser: false,
                                              timestamp: DateTime.now(),
                                              isLoading: _isStreaming,
                                            ),
                                            enableAutoScroll: _enableAutoScroll,
                                            turnNumber: 0,
                                            onContinuePressed: null,
                                            onRetryPressed: null,
                                            onCancelPressed: _cancelRetry,
                                          );
                                        }
                                      }
                                    },
                                  ),
                        ),
                        _buildBannerAd(),
                        if (_selectedImages.isNotEmpty)
                          Container(
                            height: 80,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            color: Colors.grey.shade900,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _selectedImages.length,
                              itemBuilder: (context, index) {
                                return Stack(
                                  children: [
                                    Container(
                                      width: 70,
                                      height: 70,
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        image: DecorationImage(
                                          image: MemoryImage(
                                            _selectedImages[index],
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: () => _removeImage(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.all(7),
                          color: Colors.grey.shade900,
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (_enableImageUpload)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.image,
                                          color:
                                              _selectedImages.isNotEmpty
                                                  ? Colors.orange
                                                  : Colors.white,
                                          size: 20,
                                        ),
                                        onPressed: () async {
                                          await _pickImage();
                                          if (_inputFocusNode?.hasFocus ==
                                              false) {
                                            _inputFocusNode?.requestFocus();
                                          }
                                        },
                                      ),
                                    ),
                                  Expanded(
                                    child: Container(
                                      constraints: BoxConstraints(
                                        maxHeight: _inputExpanded ? 140 : 76,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade800,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: TextField(
                                        controller: _messageController,
                                        focusNode: _inputFocusNode,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                        maxLines: _inputExpanded ? null : 3,
                                        minLines: 3,
                                        keyboardType: TextInputType.multiline,
                                        textInputAction:
                                            _inputExpanded
                                                ? TextInputAction.newline
                                                : TextInputAction.send,
                                        onSubmitted: (_) {
                                          if (!_isSendingMessage) {
                                            _sendGeminiMessage();
                                          }
                                        },
                                        decoration: InputDecoration(
                                          hintText: 'Type your message...',
                                          hintStyle: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 14,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 12,
                                              ),
                                          suffixIcon:
                                              _isStreaming
                                                  ? IconButton(
                                                    icon: const Icon(
                                                      Icons.stop,
                                                      color: Colors.red,
                                                      size: 18,
                                                    ),
                                                    onPressed: () {
                                                      _stopGenerating();
                                                    },
                                                  )
                                                  : null,
                                        ),
                                        onChanged: (value) {},
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: IconButton(
                                      icon: Icon(
                                        _inputExpanded
                                            ? Icons.expand_more
                                            : Icons.expand_less,
                                        color: Colors.white70,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _inputExpanded = !_inputExpanded;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  ValueListenableBuilder<bool>(
                                    valueListenable: _hasTextOrImages,
                                    builder: (context, hasContent, child) {
                                      return ValueListenableBuilder<bool>(
                                        valueListenable: _isSendingNotifier,
                                        builder: (context, isSending, child) {
                                          return Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  isSending || !hasContent
                                                      ? Colors.grey.shade700
                                                      : Colors.lightBlue,
                                              shape: BoxShape.circle,
                                            ),
                                            child: IconButton(
                                              icon:
                                                  isSending
                                                      ? const SizedBox(
                                                        width: 18,
                                                        height: 18,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          valueColor:
                                                              AlwaysStoppedAnimation<
                                                                Color
                                                              >(Colors.white),
                                                        ),
                                                      )
                                                      : const Icon(
                                                        Icons.send,
                                                        color: Colors.white,
                                                        size: 20,
                                                      ),
                                              onPressed: () async {
                                                if (!isSending && hasContent) {
                                                  if (_isMobile) {
                                                    HapticFeedback.lightImpact();
                                                  }
                                                  await _sendGeminiMessage();
                                                }
                                              },
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildScrollToBottomButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebView() {
    if (kIsWeb) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'WebView is not supported on web. Please use Gemini API mode.',
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('AI Assistant'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _showPlatformSelectionScreen,
        ),
        actions: [
          if (_isLoading)
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: WebViewWidget(controller: _controller)),
          _buildBannerAd(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isHiveLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: Colors.orange,
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }
    if (_showPlatformSelection) {
      return _buildPlatformSelection();
    } else if (_usingGeminiAPI) {
      return _buildGeminiAPIChat();
    } else {
      return _buildWebView();
    }
  }
}

class _ChatHistoryScreen extends StatelessWidget {
  final Widget Function() buildHistory;
  const _ChatHistoryScreen({required this.buildHistory});

  @override
  Widget build(BuildContext context) {
    return buildHistory();
  }
}

// UI Models
class GeminiModel {
  final String id;
  final String name;
  final String description;
  final String priority;
  final String bestFor;
  final bool isRecommended;

  const GeminiModel({
    required this.id,
    required this.name,
    required this.description,
    required this.priority,
    required this.bestFor,
    required this.isRecommended,
  });
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isLoading;
  final bool isError;
  final List<Uint8List>? images;
  final String? thinkingProcess;
  final Duration? thinkingTime;
  final bool isIncomplete;
  final bool canRetry;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isLoading = false,
    this.isError = false,
    this.images,
    this.thinkingProcess,
    this.thinkingTime,
    this.isIncomplete = false,
    this.canRetry = false,
  });
}

class _CodeBlock {
  final String language;
  final String code;
  _CodeBlock({required this.language, required this.code});
}

class ChatBubbleWithThinking extends StatefulWidget {
  final ChatMessage message;
  final bool enableAutoScroll;
  final int turnNumber;
  final VoidCallback? onContinuePressed;
  final VoidCallback? onRetryPressed;
  final VoidCallback? onCancelPressed;

  const ChatBubbleWithThinking({
    super.key,
    required this.message,
    this.enableAutoScroll = false,
    this.turnNumber = 0,
    this.onContinuePressed,
    this.onRetryPressed,
    this.onCancelPressed,
  });

  @override
  State<ChatBubbleWithThinking> createState() => _ChatBubbleWithThinkingState();
}

class _ChatBubbleWithThinkingState extends State<ChatBubbleWithThinking> {
  bool _isThinkingExpanded = false;
  bool _userExpanded = false;

  String _formatThinkingTime(Duration duration) {
    if (duration.inSeconds < 1) return '${duration.inMilliseconds}ms';
    if (duration.inSeconds < 60) return '${duration.inSeconds}s';
    return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
  }

  Widget _buildThinkingSection() {
    if (widget.message.thinkingProcess == null ||
        widget.message.thinkingProcess!.isEmpty) {
      return const SizedBox.shrink();
    }
    final thinkingText = widget.message.thinkingProcess!;
    final preview =
        thinkingText.length > 60
            ? '${thinkingText.substring(0, 60)}...'
            : thinkingText;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purpleAccent.withAlpha(80), width: 1),
      ),
      child: ExpansionTile(
        key: ValueKey(
          'thinking_${widget.message.timestamp.millisecondsSinceEpoch}',
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        initiallyExpanded: _isThinkingExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _isThinkingExpanded = expanded;
          });
        },
        leading: Icon(
          _isThinkingExpanded ? Icons.expand_less : Icons.expand_more,
          color: Colors.purpleAccent,
          size: 20,
        ),
        title: Row(
          children: [
            const Icon(Icons.psychology, size: 16, color: Colors.purpleAccent),
            const SizedBox(width: 8),
            Text(
              widget.message.thinkingTime != null
                  ? '🧠 Thought for ${_formatThinkingTime(widget.message.thinkingTime!)}'
                  : '🧠 Thinking Process',
              style: const TextStyle(
                color: Colors.purpleAccent,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (!_isThinkingExpanded)
              Text(
                preview,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 14,
                      color: Colors.amber,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Detailed Reasoning:',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade800),
                  ),
                  child: SelectionArea(
                    child: Text(
                      thinkingText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.5,
                      ),
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

  Widget _buildImagePreview(Uint8List imageBytes, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8, right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.memory(
          imageBytes,
          width: 150,
          height: 150,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  List<_CodeBlock> _extractCodeBlocks(String text) {
    final List<_CodeBlock> blocks = [];
    final regex = RegExp(r'```(\w*)\s*\n?([\s\S]*?)```', multiLine: true);
    for (final match in regex.allMatches(text)) {
      final language = (match.group(1) ?? '').trim();
      final code = (match.group(2) ?? '').trim();
      if (code.isNotEmpty) {
        final isDuplicate = blocks.any(
          (b) => b.code == code && b.language == language,
        );
        if (!isDuplicate) {
          blocks.add(
            _CodeBlock(
              language: language.isEmpty ? 'txt' : language,
              code: code,
            ),
          );
        }
      }
    }
    return blocks;
  }

  /// Code block now shows a COPY button directly on the left, next
  /// to the language name. Design mirrors the TABLE block.
  Widget _buildCodeBlock(_CodeBlock block, int index) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.greenAccent.withAlpha(100), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.code, size: 14, color: Colors.greenAccent),
                const SizedBox(width: 6),
                Text(
                  block.language.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                // Copy button right next to the label.
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: block.code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Code copied!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withAlpha(40),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.content_copy,
                          size: 11,
                          color: Colors.greenAccent,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Copy',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectionArea(
                child: Text(
                  block.code,
                  style: const TextStyle(
                    color: Colors.lightGreenAccent,
                    fontSize: 13,
                    fontFamily: 'Monospace',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<List<List<String>>> _extractTables(String text) {
    final tables = <List<List<String>>>[];
    final lines = text.split('\n');
    int i = 0;
    while (i < lines.length) {
      final line = lines[i].trim();
      if (line.startsWith('|') && line.endsWith('|')) {
        final block = <String>[];
        while (i < lines.length) {
          final l = lines[i].trim();
          if (l.startsWith('|') && l.endsWith('|')) {
            block.add(l);
            i++;
          } else {
            break;
          }
        }
        if (block.length >= 2) {
          final rows = <List<String>>[];
          for (final row in block) {
            if (RegExp(r'^\|[\s\-\|:]+\|$').hasMatch(row)) continue;
            final cells =
                row
                    .split('|')
                    .where((c) => c.trim().isNotEmpty || c == ' ')
                    .map((c) => c.trim())
                    .toList();
            final cleaned =
                cells.where((c) => !RegExp(r'^[\-\s:]+$').hasMatch(c)).toList();
            if (cleaned.isNotEmpty) rows.add(cleaned);
          }
          if (rows.isNotEmpty) tables.add(rows);
        }
      } else {
        i++;
      }
    }
    return tables;
  }

  /// Table header row now has a COPY button right next to "TABLE".
  Widget _buildTable(List<List<String>> rows) {
    // Flatten for copy: tab-separated values per row.
    final buffer = StringBuffer();
    for (final row in rows) {
      buffer.writeln(row.join('\t'));
    }
    final tableText = buffer.toString();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade700),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: Colors.grey.shade800,
            child: Row(
              children: [
                const Icon(Icons.table_chart, size: 14, color: Colors.orange),
                const SizedBox(width: 6),
                const Text(
                  'TABLE',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                // Copy button next to the TABLE label.
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: tableText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Table copied!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(50),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.content_copy,
                          size: 11,
                          color: Colors.orange,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Copy',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _openTableFullscreen(rows),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(50),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.open_in_full,
                          size: 12,
                          color: Colors.orange,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Expand',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                child: _buildTableWidget(rows),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableWidget(List<List<String>> rows) {
    final columnCount = rows
        .map((r) => r.length)
        .fold<int>(0, (a, b) => a > b ? a : b);
    return Table(
      defaultColumnWidth: const FixedColumnWidth(140),
      border: TableBorder.all(color: Colors.grey.shade700, width: 0.5),
      children:
          rows.map((row) {
            final padded = List<String>.from(row);
            while (padded.length < columnCount) {
              padded.add('');
            }
            return TableRow(
              children:
                  padded.map((cell) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        cell,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
            );
          }).toList(),
    );
  }

  void _openTableFullscreen(List<List<String>> rows) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                title: const Text('Table'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              body: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(16),
                    child: _buildTableWidget(rows),
                  ),
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildParsedText(String text) {
    final tables = _extractTables(text);
    final codeBlocks = _extractCodeBlocks(text);

    if (tables.isEmpty && codeBlocks.isEmpty) {
      return SelectionArea(
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      );
    }

    if (tables.isNotEmpty) {
      final widgets = <Widget>[];
      final lines = text.split('\n');
      final buffer = <String>[];
      int i = 0;
      while (i < lines.length) {
        final l = lines[i].trim();
        if (l.startsWith('|') && l.endsWith('|')) {
          if (buffer.isNotEmpty) {
            final plain = buffer.join('\n').trim();
            if (plain.isNotEmpty) {
              widgets.add(
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: SelectionArea(
                    child: Text(
                      plain,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              );
            }
            buffer.clear();
          }
          final tableLines = <String>[];
          while (i < lines.length &&
              lines[i].trim().startsWith('|') &&
              lines[i].trim().endsWith('|')) {
            tableLines.add(lines[i].trim());
            i++;
          }
          final parsedTables = _extractTables(tableLines.join('\n'));
          if (parsedTables.isNotEmpty) {
            widgets.add(_buildTable(parsedTables.first));
          }
        } else {
          buffer.add(lines[i]);
          i++;
        }
      }
      if (buffer.isNotEmpty) {
        final plain = buffer.join('\n').trim();
        if (plain.isNotEmpty) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SelectionArea(
                child: Text(
                  plain,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          );
        }
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      );
    }

    String remainingText = text;
    final List<Widget> widgets = [];
    for (int i = 0; i < codeBlocks.length; i++) {
      final block = codeBlocks[i];
      final codePattern = '```${block.language}\n${block.code}\n```';
      final parts = remainingText.split(codePattern);
      if (parts.isNotEmpty && parts[0].trim().isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SelectionArea(
              child: Text(
                parts[0].trim(),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        );
      }
      widgets.add(_buildCodeBlock(block, i));
      if (parts.length > 1) {
        remainingText = parts.sublist(1).join(codePattern);
      } else {
        remainingText = '';
      }
    }
    if (remainingText.trim().isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SelectionArea(
            child: Text(
              remainingText.trim(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildMessageContent(ChatMessage message) {
    if (message.isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.text.isNotEmpty) ...[
            Expanded(child: _buildParsedText(message.text)),
            const SizedBox(width: 8),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ] else ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Thinking...', style: TextStyle(color: Colors.white)),
            ),
          ],
        ],
      );
    } else if (message.isError) {
      final displayText =
          message.text.isEmpty
              ? '⚠️ An error occurred. Tap Retry to try again.'
              : message.text;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayText,
            style: const TextStyle(color: Colors.redAccent, fontSize: 14),
          ),
          if (message.canRetry) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _buildRetryButton(),
                const SizedBox(width: 8),
                _buildCancelButton(),
              ],
            ),
          ],
        ],
      );
    } else if (message.text.isEmpty && !message.isLoading) {
      return const Text(
        '⚠️ Empty response received. Please try again.',
        style: TextStyle(color: Colors.orange, fontSize: 14),
      );
    } else {
      return _buildParsedText(message.text);
    }
  }

  Widget _buildCancelButton() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: ElevatedButton(
        onPressed: widget.onCancelPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.withAlpha(30),
          foregroundColor: Colors.redAccent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.redAccent.withAlpha(100), width: 1),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel, size: 16),
            SizedBox(width: 8),
            Text('Cancel'),
          ],
        ),
      ),
    );
  }

  void _copyFullMessage() {
    Clipboard.setData(ClipboardData(text: widget.message.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Full message copied!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: ElevatedButton(
        onPressed: widget.onContinuePressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.withAlpha(30),
          foregroundColor: Colors.orange,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.orange.withAlpha(100), width: 1),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_right_alt, size: 16),
            SizedBox(width: 8),
            Text('Continue'),
          ],
        ),
      ),
    );
  }

  Widget _buildRetryButton() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: ElevatedButton(
        onPressed: widget.onRetryPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal.withAlpha(30),
          foregroundColor: Colors.tealAccent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.tealAccent.withAlpha(100), width: 1),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh, size: 16),
            SizedBox(width: 8),
            Text('Retry'),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (widget.message.isUser ||
        widget.message.isLoading ||
        widget.message.text.isEmpty ||
        widget.message.isError) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          InkWell(
            onTap: _copyFullMessage,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(30),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withAlpha(100), width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.content_copy, size: 14, color: Colors.blue),
                  SizedBox(width: 6),
                  Text(
                    'Copy',
                    style: TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (widget.onRetryPressed != null)
            InkWell(
              onTap: widget.onRetryPressed,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(30),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.green.withAlpha(100),
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, size: 14, color: Colors.green),
                    SizedBox(width: 6),
                    Text(
                      'Regenerate',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserCollapsibleText(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: () => setState(() => _userExpanded = !_userExpanded),
          child: Text(
            text,
            maxLines: _userExpanded ? null : 1,
            overflow:
                _userExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => setState(() => _userExpanded = !_userExpanded),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _userExpanded ? Icons.expand_less : Icons.expand_more,
                size: 14,
                color: Colors.white70,
              ),
              Text(
                _userExpanded ? 'Show less' : 'Show more',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.turnNumber > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 6),
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Colors.lightBlue,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${widget.turnNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Expanded(
            child: Align(
              alignment:
                  message.isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.99,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!message.isUser &&
                        message.thinkingProcess != null &&
                        message.thinkingProcess!.isNotEmpty)
                      _buildThinkingSection(),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            message.isUser
                                ? Colors.blue.shade900
                                : Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              message.isUser
                                  ? Colors.blueAccent
                                  : (message.isError
                                      ? Colors.redAccent
                                      : Colors.grey.shade700),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            message.isUser
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                        children: [
                          if (message.images != null &&
                              message.images!.isNotEmpty)
                            Container(
                              margin: EdgeInsets.only(
                                bottom: message.text.isNotEmpty ? 8 : 0,
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children:
                                    message.images!.asMap().entries.map((
                                      entry,
                                    ) {
                                      return _buildImagePreview(
                                        entry.value,
                                        entry.key,
                                      );
                                    }).toList(),
                              ),
                            ),
                          if (message.isUser && message.text.isNotEmpty)
                            _buildUserCollapsibleText(message.text)
                          else
                            _buildMessageContent(message),
                          if (message.isUser &&
                              message.text.isEmpty &&
                              message.images != null &&
                              message.images!.isNotEmpty &&
                              !message.isLoading)
                            const Text(
                              '[Image attached]',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          if (message.isError &&
                              widget.onRetryPressed != null &&
                              message.canRetry)
                            _buildRetryButton(),
                          if (message.isIncomplete &&
                              !message.isUser &&
                              !message.isError &&
                              widget.onContinuePressed != null)
                            _buildContinueButton(),
                          if (!message.isError && !message.isUser)
                            _buildActionButtons(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AIPlatform {
  final String name;
  final String url;
  final IconData icon;
  final Color color;
  final String description;

  const AIPlatform({
    required this.name,
    required this.url,
    required this.icon,
    required this.color,
    required this.description,
  });
}

class _ParsedResponse {
  final String thinkingProcess;
  final String finalResponse;
  _ParsedResponse({required this.thinkingProcess, required this.finalResponse});
}
