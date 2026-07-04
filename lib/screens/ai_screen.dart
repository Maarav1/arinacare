import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

//import 'package:webview_flutter_web/webview_flutter_web.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'hive_models.dart';

class AIScreen extends StatefulWidget {
  const AIScreen({super.key});

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen>
    with AutomaticKeepAliveClientMixin {
  late final WebViewController _controller;
  bool _isLoading = false;
  bool _showPlatformSelection = true;
  bool _usingGeminiAPI = false;
  FocusNode? _inputFocusNode;

  // Ad variables
  late BannerAd _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isBannerAdLoaded = false;
  bool _isInterstitialAdLoaded = false;
  Timer? _interstitialTimer;

  // Hive boxes
  late Box<ChatMessageHive> _chatBox;
  late Box<ConversationHive> _conversationBox;
  late Box<UserProfileHive> _userProfileBox;

  // Gemini API variables
  String _geminiApiKey = '';
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _geminiInitialized = false;
  bool _isSendingMessage = false;
  bool _enableThinking = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _interestsController = TextEditingController();

  // Streaming variables
  String _currentStreamText = '';
  StreamSubscription<String>? _streamSubscription;
  bool _isStreaming = false;
  late ScrollController _scrollController;

  // Continue response variables
  String _lastIncompleteResponse = '';
  bool _isContinuingResponse = false;

  // Error handling and retry
  int _retryCount = 0;
  static const int _maxRetries = 3;
  String? _lastFailedPrompt;
  List<Uint8List>? _lastFailedImages;
  bool _hasPartialResponse = false;
  String _partialResponseOnError = '';

  // Model selection variables
  String _selectedModel = 'gemini-2.5-flash';
  final List<GeminiModel> _availableModels = [
    GeminiModel(
      id: 'gemini-2.5-flash',
      name: 'Gemini 2.5 Flash',
      description: 'High-speed chat',
      priority: 'Recommended',
      bestFor: 'Most applications',
      isRecommended: true,
    ),
    GeminiModel(
      id: 'gemini-flash-latest',
      name: 'Gemini 2.5 Pro',
      description: 'Complex reasoning',
      priority: 'High Reasoning',
      bestFor: 'Advanced tasks',
      isRecommended: false,
    ),
    GeminiModel(
      id: 'gemini-2.5-flash-lite',
      name: 'Gemini 2.5 Flash Latest',
      description: 'Latest updates',
      priority: 'Cutting Edge',
      bestFor: 'Latest features',
      isRecommended: false,
    ),
    GeminiModel(
      id: 'gemini-3-flash-preview',
      name: 'Gemini 3 Flash Preview',
      description: 'PhD-level reasoning',
      priority: 'Newest Frontier',
      bestFor: 'Latest model',
      isRecommended: false,
    ),
  ];

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

  // Image picker
  final ImagePicker _picker = ImagePicker();
  final List<Uint8List> _selectedImages = [];

  // Settings
  bool _enableAutoScroll = true;
  bool _enableStreaming = true;
  bool _enableImageUpload = true;
  bool _enableHistory = true;
  double _temperature = 0.2;

  // Smart context settings
  int _maxContextMessages = 10;
  bool _enableSmartContext = true;

  // Thinking mode tracking
  final Stopwatch _thinkingStopwatch = Stopwatch();
  String _currentThinkingProcess = '';
  bool _isThinkingComplete = false;
  bool _isThinkingPhase = false;

  // Web search
  final bool _enableWebSearch = false;

  // Auto-scroll timer
  Timer? _autoScrollTimer;

  // NEW: Scroll button visibility timer
  Timer? _scrollButtonTimer;
  bool _showScrollButton = false;
  bool _userScrolledUp = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeHive();
    _initializeApiKey();
    _initializeWebView();
    _initializeFocusNode();

    // ===== WEB COMPATIBILITY: Skip ads on web =====
    if (!kIsWeb) {
      // Initialize ads only on mobile
      MobileAds.instance.initialize();
      _loadBannerAd();
      _loadInterstitialAd();
      _startInterstitialTimer();
    }

    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _scrollController.addListener(_updateScrollIndicator); 
    _messageController.addListener(_onMessageTextChanged);
  }

  void _onMessageTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _updateScrollIndicator() {
    if (mounted) {
      setState(() {});
    }
  }

  // NEW: Scroll listener for button visibility
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
  }

  // NEW: Reset scroll button auto-hide timer
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
    _inputFocusNode = FocusNode(
      onKeyEvent: (node, event) {
        return KeyEventResult.ignored;
      },
    );
  }

  @override
  void dispose() {
    _cleanupResources();
    super.dispose();
  }

  Future<void> _cleanupResources() async {
    await _cancelCurrentStream();
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _scrollButtonTimer?.cancel();
    _scrollButtonTimer = null;
    _scrollController.removeListener(_onScroll);
    _messageController.removeListener(_onMessageTextChanged);
    _messageController.dispose();
    _nameController.dispose();
    _interestsController.dispose();
    _inputFocusNode?.dispose();
    _scrollController.dispose();

    // ===== WEB COMPATIBILITY: Only dispose ads on mobile =====
    if (!kIsWeb) {
      _bannerAd.dispose();
      _interstitialTimer?.cancel();
      if (_interstitialAd != null) {
        _interstitialAd!.dispose();
      }
    }

    await _saveConversation();
  }

  Future<void> _initializeHive() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChatMessageHiveAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ConversationHiveAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(UserProfileHiveAdapter());
    }

    await Hive.initFlutter();

    _chatBox = await Hive.openBox<ChatMessageHive>('chat_messages');
    _conversationBox = await Hive.openBox<ConversationHive>('conversations');
    _userProfileBox = await Hive.openBox<UserProfileHive>('user_profile');

    await _loadUserProfile();
    await _loadChatHistoryForModel(_selectedModel);
    _cleanOldConversations();
  }

  void _cleanOldConversations() async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    final oldConversations =
        _conversationBox.values
            .where((conv) => conv.lastMessageTimestamp.isBefore(thirtyDaysAgo))
            .toList();

    for (final conv in oldConversations) {
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

  void _initializeApiKey() {
    if (kIsWeb) {
      // On web: proxy handles auth — no key needed in app
      // Set initialized to true always on web since proxy is always available
      _geminiApiKey = 'proxy';
      _geminiInitialized = true;
    } else {
      try {
        if (dotenv.isEveryDefined(['GEMINI_API_KEY'])) {
          _geminiApiKey = dotenv.get('GEMINI_API_KEY');
        } else {
          _geminiApiKey = '';
        }
      } catch (e) {
        if (kDebugMode) print('Error loading API Key: $e');
        _geminiApiKey = '';
      }
      _geminiInitialized = _geminiApiKey.isNotEmpty;
    }

    if (_geminiInitialized && kDebugMode) {
      if (kDebugMode) {
        print('✅ Gemini API Key loaded successfully');
      }
    } else if (!_geminiInitialized && kDebugMode) {
      if (kDebugMode) {
        print('❌ Gemini API Key not found — check secrets or .env');
      }
    }
  }

  // Banner Ad Methods
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

  // Interstitial Ad Methods
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
    // ===== WEB COMPATIBILITY: No ads on web =====
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    if (!_isBannerAdLoaded) {
      return const SizedBox.shrink();
    }
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
      if (kDebugMode) {
        print('Image picker error: $e');
      }
    }
  }

  Future<void> _removeImage(int index) async {
    if (mounted) {
      setState(() {
        _selectedImages.removeAt(index);
      });
    }
  }

  void _changeModel(String newModel) async {
    await _saveConversation();
    await _cancelCurrentStream();

    if (!mounted) return;

    setState(() {
      _selectedModel = newModel;
      _messages.clear();
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

  Future<void> _loadChatHistoryForModel(String modelId) async {
    if (!_enableHistory) return;

    try {
      final conversations =
          _conversationBox.values
              .where((conv) => conv.modelUsed == modelId)
              .toList()
            ..sort(
              (a, b) =>
                  b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp),
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
            _messages.addAll(
              messages.map(
                (msg) => ChatMessage(
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
              ),
            );
          });

          if (kDebugMode) {
            print('✅ Loaded ${messages.length} messages for model: $modelId');
          }
          // Restore continue state from loaded history
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
        if (kDebugMode) {
          print('📭 No saved conversation found for model: $modelId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading chat history for model $modelId: $e');
      }
    }
  }

  bool _isTimeSensitiveQuery(String query) {
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
1. Focus ONLY on the user's CURRENT/LATEST message
2. The previous messages are provided for context flow and continuity ONLY
3. Do NOT repeat, rehash, or discuss previous messages unless specifically asked
4. Answer the CURRENT question directly and completely
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

    final isTimeSensitive = _isTimeSensitiveQuery(currentPrompt);
    if (isTimeSensitive && !_enableWebSearch) {
      systemPrompt +=
          '\n\nNote: For time-sensitive info, acknowledge your knowledge cutoff.';
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
              'Understood. I will focus on the CURRENT message and use previous context only for continuity.${hasUserInfo && userName.isNotEmpty ? ' I know your name is $userName.' : ''} Current date: $currentDate, year: $currentYear.${_enableThinking ? ' I will use the thinking format as specified.' : ''}',
        },
      ],
    });

    if (_enableSmartContext && _messages.isNotEmpty) {
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
            {'text': 'Noted. I\'ll focus on recent context.'},
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
      {
        'text':
            '>>> NEW REQUEST (Please focus on answering THIS specifically) <<<\n\n$currentPrompt',
      },
    ];

    if (currentImages != null && currentImages.isNotEmpty) {
      for (var imageBytes in currentImages) {
        currentParts.add({
          'inline_data': {
            'mime_type': 'image/jpeg',
            'data': base64Encode(imageBytes),
          },
        });
      }
    }

    contents.add({'role': 'user', 'parts': currentParts});

    return contents;
  }

  Stream<String> _streamGeminiResponse(
    String prompt, {
    List<Uint8List>? images,
  }) async* {
    // ===== WEB COMPATIBILITY: Use Cloud Function proxy on web =====
    final String url =
        kIsWeb
            ? 'https://us-central1-lifematters-c466d.cloudfunctions.net/geminiProxy?model=$_selectedModel&streaming=true'
            : 'https://generativelanguage.googleapis.com/v1beta/models/$_selectedModel:streamGenerateContent?alt=sse&key=$_geminiApiKey';

    final headers = {'Content-Type': 'application/json'};

    final contents = _buildSmartContext(prompt, images);

    final requestBody = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        'temperature': _temperature,
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 65536,
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
        {
          'google_search': {}, // <-- This activates real-time search
        },
      ],
    };

    if (kDebugMode) {
      print(
        '🔗 Sending request with SMART CONTEXT (max $_maxContextMessages messages)',
      );
      print('📝 Current prompt: $prompt');
      if (images != null && images.isNotEmpty) {
        print('🖼️ Images: ${images.length}');
      }
    }

    try {
      final request = http.Request('POST', Uri.parse(url));
      request.headers.addAll(headers);
      request.body = jsonEncode(requestBody);

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        throw Exception(
          'API request failed with status ${streamedResponse.statusCode}: $errorBody',
        );
      }

      String buffer = '';
      await for (final chunk in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (chunk.trim().isEmpty) continue;

        if (chunk.startsWith('data: ')) {
          final jsonString = chunk.substring(6);

          if (jsonString == '[DONE]') {
            if (kDebugMode) {
              print('✅ Streaming complete');
            }
            break;
          }

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
                      continue;
                    }

                    yield buffer;
                    buffer = '';
                  }
                }
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ JSON parsing error: $e');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Stream request error: $e');
      }
      rethrow;
    }
  }

  Future<void> _retryFailedRequest() async {
    if (_lastFailedPrompt == null) {
      // Recover last user message as the failed prompt
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

    if (mounted) {
      setState(() {
        if (_messages.isNotEmpty && _messages.last.isError) {
          _messages.removeLast();
        }
      });
    }

    await _sendGeminiMessageInternal(
      _lastFailedPrompt!,
      images: _lastFailedImages,
      isRetry: true,
    );
  }

  // FIX: Continue now properly appends to existing response
  Future<void> _continueIncompleteResponse() async {
    // Recover incomplete text from messages list if state was lost
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

    if (_isContinuingResponse || _lastIncompleteResponse.isEmpty) {
      return;
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

    try {
      String accumulatedResponse = '';

      _streamSubscription = _streamGeminiResponse(
        "Continue your previous response from exactly where you stopped. Do not repeat what you already said. Just continue the text seamlessly.",
      ).listen(
        (chunk) {
          if (!mounted) return;

          setState(() {
            accumulatedResponse += chunk;
            _currentStreamText = accumulatedResponse;
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
            _resetContinueState();
          });
        },
        onDone: () async {
          if (!mounted) return;

          // FIX: Properly append without spaces
          final continuedResponse =
              _lastIncompleteResponse + accumulatedResponse;

          setState(() {
            _messages.removeWhere((msg) => msg.text == _lastIncompleteResponse);
            _messages.add(
              ChatMessage(
                text: continuedResponse,
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
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
        _resetContinueState();
      });
    }
  }

  void _resetContinueState() {
    _isContinuingResponse = false;
    _isSendingMessage = false;
    _isStreaming = false;
    _currentStreamText = '';
    _currentThinkingProcess = '';
    _isThinkingComplete = false;
    _isThinkingPhase = false;
  }

  _ParsedResponse _parseThinkingResponse(String fullResponse) {
    if (_enableThinking) {
      final thinkingStartMarker = 'THINKING_START';
      final thinkingEndMarker = 'THINKING_END';

      if (fullResponse.contains(thinkingStartMarker) &&
          fullResponse.contains(thinkingEndMarker)) {
        final startIndex = fullResponse.indexOf(thinkingStartMarker);
        final endIndex = fullResponse.indexOf(thinkingEndMarker);

        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          final thinkingStart = startIndex + thinkingStartMarker.length;
          final thinkingProcess =
              fullResponse.substring(thinkingStart, endIndex).trim();

          final finalResponse =
              fullResponse
                  .substring(endIndex + thinkingEndMarker.length)
                  .trim();

          return _ParsedResponse(
            thinkingProcess: thinkingProcess,
            finalResponse: finalResponse,
          );
        }
      }
    }

    return _ParsedResponse(thinkingProcess: '', finalResponse: fullResponse);
  }

  Future<void> _saveConversation() async {
    if (!_enableHistory || _messages.isEmpty) return;

    try {
      final conversations =
          _conversationBox.values
              .where((conv) => conv.modelUsed == _selectedModel)
              .toList()
            ..sort(
              (a, b) =>
                  b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp),
            );

      ConversationHive currentConversation;

      if (conversations.isNotEmpty) {
        currentConversation = conversations.first;
        currentConversation.lastMessageTimestamp = DateTime.now();
        currentConversation.messageCount = _messages.length;
        await currentConversation.save();
      } else {
        final conversationId = DateTime.now().millisecondsSinceEpoch.toString();
        currentConversation =
            ConversationHive()
              ..id = conversationId
              ..lastMessageTimestamp = DateTime.now()
              ..messageCount = _messages.length
              ..modelUsed = _selectedModel;

        await _conversationBox.add(currentConversation);
      }

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

      if (kDebugMode) {
        print('✅ Saved conversation for model: $_selectedModel');
        print('📊 Message count: ${_messages.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving conversation for model $_selectedModel: $e');
      }
    }
  }

  Future<void> _sendGeminiMessage() async {
    final String message = _messageController.text.trim();
    final List<Uint8List> images = List.from(_selectedImages);

    if (message.isEmpty && images.isEmpty) return;
    if (_isSendingMessage) return;

    _messageController.clear();

    if (mounted) {
      setState(() {
        _selectedImages.clear();
        _isSendingMessage = true;
      });
    }

    await _sendGeminiMessageInternal(
      message.isEmpty ? "[Image analysis request]" : message,
      images: images.isNotEmpty ? images : null,
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
    }

    await _cancelCurrentStream();

    if (mounted) {
      setState(() {
        _isStreaming = true;
        _currentThinkingProcess = '';
        _isThinkingComplete = false;
        _isThinkingPhase = false;
        _currentStreamText = '';

        if (!isRetry) {
          _messages.add(
            ChatMessage(
              text: prompt,
              isUser: true,
              timestamp: DateTime.now(),
              images: images?.isNotEmpty == true ? List.from(images!) : null,
            ),
          );
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
                  _currentStreamText = parsed.finalResponse;
                }
              } else if (_isThinkingComplete) {
                final parsed = _parseThinkingResponse(accumulatedResponse);
                _currentStreamText = parsed.finalResponse;
              }
            } else {
              _currentStreamText = accumulatedResponse;
            }
          });

          _scheduleAutoScroll();
        },
        onError: (error) {
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
                  thinkingProcess:
                      _currentThinkingProcess.isNotEmpty
                          ? _currentThinkingProcess
                          : null,
                  thinkingTime:
                      _currentThinkingProcess.isNotEmpty
                          ? _thinkingStopwatch.elapsed
                          : null,
                ),
              );
            }

            _messages.add(
              ChatMessage(
                text:
                    'Error: ${error.toString()}\n\n${_retryCount < _maxRetries ? "Tap Retry below to try again." : "Maximum retries reached."}',
                isUser: false,
                timestamp: DateTime.now(),
                isError: true,
                canRetry: _retryCount < _maxRetries,
              ),
            );
            _resetMessageState();
          });
        },
        onDone: () async {
          if (!mounted) return;

          final parsedResponse = _parseThinkingResponse(accumulatedResponse);
          final finalOutput =
              parsedResponse.finalResponse.isNotEmpty
                  ? parsedResponse.finalResponse
                  : _currentStreamText;

          final bool seemsIncomplete = _checkIfResponseIncomplete(finalOutput);

          setState(() {
            if (seemsIncomplete) {
              _lastIncompleteResponse = finalOutput;
              _messages.add(
                ChatMessage(
                  text: finalOutput,
                  isUser: false,
                  timestamp: DateTime.now(),
                  thinkingProcess:
                      _currentThinkingProcess.isNotEmpty
                          ? _currentThinkingProcess
                          : null,
                  thinkingTime:
                      _currentThinkingProcess.isNotEmpty
                          ? _thinkingStopwatch.elapsed
                          : null,
                  isIncomplete: true,
                ),
              );
            } else {
              _messages.add(
                ChatMessage(
                  text: finalOutput,
                  isUser: false,
                  timestamp: DateTime.now(),
                  thinkingProcess:
                      _currentThinkingProcess.isNotEmpty
                          ? _currentThinkingProcess
                          : null,
                  thinkingTime:
                      _currentThinkingProcess.isNotEmpty
                          ? _thinkingStopwatch.elapsed
                          : null,
                ),
              );
            }
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
        }

        _messages.add(
          ChatMessage(
            text:
                'Failed to get response: ${e.toString()}\n\n${_retryCount < _maxRetries ? "Tap Retry to try again." : "Max retries reached."}',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
            canRetry: _retryCount < _maxRetries,
          ),
        );
        _resetMessageState();
      });
    }
  }

  void _resetMessageState() {
    _isSendingMessage = false;
    _isStreaming = false;
    _currentStreamText = '';
    _currentThinkingProcess = '';
    _isThinkingComplete = false;
    _isThinkingPhase = false;
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

  Future<void> _loadUserProfile() async {
    try {
      final profiles = _userProfileBox.values.toList();
      if (profiles.isNotEmpty) {
        final profile = profiles.first;
        _nameController.text = profile.name;
        _interestsController.text = profile.interests;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading user profile: $e');
      }
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

      if (mounted) {
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
      if (kDebugMode) {
        print('❌ Error saving user profile: $e');
      }

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
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
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
      });
    }
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
            builder: (context, setState) {
              return Container(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildSettingsSection(
                        title: 'Chat Settings',
                        children: [
                          SwitchListTile(
                            title: const Text(
                              'Auto-scroll',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: const Text(
                              'Automatically scroll to new messages',
                              style: TextStyle(color: Colors.white54),
                            ),
                            value: _enableAutoScroll,
                            activeColor: Colors.orange,
                            onChanged: (value) {
                              setState(() {
                                _enableAutoScroll = value;
                              });
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  this.setState(() {
                                    _enableAutoScroll = value;
                                  });
                                }
                              });
                            },
                          ),
                          SwitchListTile(
                            title: const Text(
                              'Streaming',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: const Text(
                              'Enable real-time response streaming',
                              style: TextStyle(color: Colors.white54),
                            ),
                            value: _enableStreaming,
                            activeColor: Colors.orange,
                            onChanged: (value) {
                              setState(() {
                                _enableStreaming = value;
                              });
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  this.setState(() {
                                    _enableStreaming = value;
                                  });
                                }
                              });
                            },
                          ),
                          SwitchListTile(
                            title: const Text(
                              'Chat History',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: const Text(
                              'Save and load chat conversations',
                              style: TextStyle(color: Colors.white54),
                            ),
                            value: _enableHistory,
                            activeColor: Colors.orange,
                            onChanged: (value) {
                              setState(() {
                                _enableHistory = value;
                              });
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  this.setState(() {
                                    _enableHistory = value;
                                    if (value) {
                                      _loadChatHistoryForModel(_selectedModel);
                                    } else {
                                      _messages.clear();
                                    }
                                  });
                                }
                              });
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
                              setState(() {
                                _enableSmartContext = value;
                              });
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  this.setState(() {
                                    _enableSmartContext = value;
                                  });
                                }
                              });
                            },
                          ),
                          ListTile(
                            title: const Text(
                              'Context Window Size',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              '$_maxContextMessages messages',
                              style: const TextStyle(color: Colors.white54),
                            ),
                            trailing: SizedBox(
                              width: 150,
                              child: Slider(
                                value: _maxContextMessages.toDouble(),
                                min: 5,
                                max: 50,
                                divisions: 9,
                                activeColor: Colors.green,
                                inactiveColor: Colors.grey.shade700,
                                onChanged: (value) {
                                  setState(() {
                                    _maxContextMessages = value.toInt();
                                  });
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted) {
                                      this.setState(() {
                                        _maxContextMessages = value.toInt();
                                      });
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildSettingsSection(
                        title: 'Input Settings',
                        children: [
                          SwitchListTile(
                            title: const Text(
                              'Image Upload',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: const Text(
                              'Allow uploading images to AI',
                              style: TextStyle(color: Colors.white54),
                            ),
                            value: _enableImageUpload,
                            activeColor: Colors.orange,
                            onChanged: (value) {
                              setState(() {
                                _enableImageUpload = value;
                              });
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  this.setState(() {
                                    _enableImageUpload = value;
                                  });
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildSettingsSection(
                        title: 'AI Settings',
                        children: [
                          ListTile(
                            title: const Text(
                              'Temperature',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              '${_temperature.toStringAsFixed(1)} (Higher = more creative)',
                              style: const TextStyle(color: Colors.white54),
                            ),
                            trailing: SizedBox(
                              width: 150,
                              child: Slider(
                                value: _temperature,
                                min: 0.0,
                                max: 1.0,
                                divisions: 10,
                                activeColor: Colors.orange,
                                inactiveColor: Colors.grey.shade700,
                                onChanged: (value) {
                                  setState(() {
                                    _temperature = value;
                                  });
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted) {
                                      this.setState(() {
                                        _temperature = value;
                                      });
                                    }
                                  });
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

  // FIX: Instant scroll - milliseconds not minutes
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      setState(() {
        _showScrollButton = false;
        _userScrolledUp = false;
      });
    }
  }

  // FIX: Scroll button on LEFT side
  Widget _buildScrollToBottomButton() {
    if (!_showScrollButton) return const SizedBox.shrink();

    return Positioned(
      bottom: 80,
      left: 12, // MOVED TO LEFT
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

    // ============================================================
  // SCROLL PROGRESS INDICATOR - Shows position and message markers
  // ============================================================
  Widget _buildScrollProgressIndicator() {
    if (!kIsWeb || _messages.isEmpty || !_scrollController.hasClients) {
      return const SizedBox.shrink();
    }

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return const SizedBox.shrink();

    final currentScroll = _scrollController.offset;
    final progress = (currentScroll / maxScroll).clamp(0.0, 1.0);

    // Calculate available height (between top bar and input)
    final screenHeight = MediaQuery.of(context).size.height;
    final topBarHeight = 60.0;
    final inputHeight = 80.0;
    final availableHeight = screenHeight - topBarHeight - inputHeight - 120;

    return Positioned(
      right: 8,
      top: topBarHeight + 20,
      bottom: inputHeight + 40,
      child: GestureDetector(
        onTapDown: (details) {
          final position = details.localPosition.dy / availableHeight;
          final targetOffset = (position.clamp(0.0, 1.0)) * maxScroll;
          _scrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        },
        onPanUpdate: (details) {
          final position = (details.localPosition.dy / availableHeight).clamp(
            0.0,
            1.0,
          );
          final targetOffset = position * maxScroll;
          _scrollController.jumpTo(targetOffset);
        },
        child: Container(
          width: 6,
          decoration: BoxDecoration(
            color: Colors.grey.shade800.withAlpha(80), 
            borderRadius: BorderRadius.circular(3),
          ),
          child: Stack(
            children: [
              // Progress fill
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: (progress * availableHeight).clamp(
                  0.0,
                  availableHeight,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              // Message markers (the "dashes")
              ..._messages.asMap().entries.map((entry) {
                final index = entry.key;
                final position = (index / _messages.length) * availableHeight;
                return Positioned(
                  top: position - 1,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    color: Colors.blue.withAlpha(80), 
                  ),
                );
              }),
              // Current position indicator (circle)
              Positioned(
                top: (progress * availableHeight) - 5,
                left: -3,
                right: -3,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(80), 
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // Tooltip on hover - show message number
              if (_messages.isNotEmpty)
                Positioned(
                  top: (progress * availableHeight) - 20,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade700),
                    ),
                    child: Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadUrl(String url) async {
    await _cancelCurrentStream();

    if (url == 'gemini://api') {
      if (!_geminiInitialized || _geminiApiKey.isEmpty) {
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
          // FIX: On web the navigation delegate is not registered so
          // _isLoading would never be reset to false. Keep it false on web.
          _isLoading = !kIsWeb;
        });
      }
      await _controller.loadRequest(Uri.parse(url));
    }
  }

  void _showApiErrorDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Gemini API Not Available'),
            content: const Text(
              'Gemini API is not configured properly. Please check your API key configuration.',
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
              'Help me get to know you better for more personalized conversations!',
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
              maxLines: null, // NO MAX LINES - unlimited input
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText:
                    'What topics are you interested in?\nExample: technology, science, art, sports, gaming, music, movies, books, travel, food, fitness, business, education...',
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
            const SizedBox(height: 20),
            const Text(
              'You can write as much as you want here. The more details you provide, the better I can personalize our conversations.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
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
                      'This information is stored locally on your device and helps me personalize our conversations. It is never sent to any external servers.',
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

  void _clearChatHistory() async {
    final modelName =
        _availableModels.firstWhere((m) => m.id == _selectedModel).name;

    final shouldClear = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear Chat History'),
            content: Text(
              'Are you sure you want to clear chat history for $modelName? This cannot be undone.',
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

    if (shouldClear != true) return;

    try {
      final conversations =
          _conversationBox.values
              .where((conv) => conv.modelUsed == _selectedModel)
              .toList();

      for (final conv in conversations) {
        final messagesToDelete =
            _chatBox.values
                .where((msg) => msg.conversationId == conv.id)
                .toList();

        for (final msg in messagesToDelete) {
          await msg.delete();
        }

        await conv.delete();
      }

      if (mounted) {
        setState(() {
          _messages.clear();
          _currentStreamText = '';
          _currentThinkingProcess = '';
          _isThinkingComplete = false;
          _isThinkingPhase = false;
          _lastIncompleteResponse = '';
          _retryCount = 0;
          _lastFailedPrompt = null;
          _lastFailedImages = null;
        });
      }

      if (kDebugMode) {
        print('✅ Cleared chat history for model: $_selectedModel');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cleared chat history for $modelName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error clearing chat history: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to clear chat history'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _shareConversation() async {
    if (_messages.isEmpty) return;

    final conversationText = _messages
        .map((msg) {
          final sender = msg.isUser ? 'You' : 'Gemini';
          final time = DateFormat('HH:mm').format(msg.timestamp);
          return '[$time] $sender: ${msg.text}';
        })
        .join('\n\n');

    final params = ShareParams(
      text: conversationText,
      subject: 'My AI Conversation',
    );

    await SharePlus.instance.share(params);
  }

  void _initializeWebView() {
    // ===== WEB COMPATIBILITY =====
    // webview_flutter now handles web automatically
    // No need to set WebViewPlatform.instance on web anymore

    // Now create the controller with the appropriate platform
    late final PlatformWebViewControllerCreationParams params;

    if (!kIsWeb) {
      // Mobile: Use native implementations
      if (WebViewPlatform.instance is WebKitWebViewPlatform) {
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
          mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        );
      } else {
        params = const PlatformWebViewControllerCreationParams();
      }
    } else {
      // Web: Use web params
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    // ===== MOBILE ONLY SETTINGS =====
    if (!kIsWeb) {
      controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      controller.setBackgroundColor(const Color(0x00000000));
    }

    // ===== NAVIGATION DELEGATE (MOBILE ONLY) =====
    if (!kIsWeb) {
      controller.setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _isLoading = progress < 100;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            _applyAccuracySettings(url);
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            if (kDebugMode) {
              print('WebView Error: ${error.description}');
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
          onUrlChange: (UrlChange change) {
            if (kDebugMode) {
              print('URL changed to: ${change.url}');
            }
          },
        ),
      );
    }

    // ===== ANDROID SPECIFIC SETTINGS (MOBILE ONLY) =====
    if (!kIsWeb && controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller;

    // ===== WEB COMPATIBILITY: Skip user agent on web =====
    if (!kIsWeb) {
      _setUserAgent();
    }
  }

  void _applyAccuracySettings(String url) {
    // ===== WEB COMPATIBILITY: runJavaScript might not work on web =====
    if (kIsWeb) return;

    final jsCode = """
    function setAccuracySettings() {
      document.body.style.backgroundColor = '#000000';
      document.body.style.color = '#ffffff';
      
      if (window.location.href.includes('chat.openai.com')) {
        setTimeout(() => {
          const preciseElements = document.querySelectorAll('[class*="precise"], [class*="accurate"], [class*="temperature"');
          preciseElements.forEach(el => {
            if (el.textContent?.toLowerCase().includes('precise') || 
                el.textContent?.toLowerCase().includes('accurate')) {
              el.click();
            }
          });
        }, 2000);
      }
    }
    
    setAccuracySettings();
    
    const observer = new MutationObserver(setAccuracySettings);
    observer.observe(document.body, {
      childList: true,
      subtree: true,
      attributes: true,
    });
  """;

    try {
      _controller.runJavaScript(jsCode);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to run JavaScript: $e');
      }
    }
  }

  void _setUserAgent() async {
    // ===== WEB COMPATIBILITY: User agent not needed on web =====
    if (kIsWeb) return;

    const desktopUserAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

    try {
      await _controller.setUserAgent(desktopUserAgent);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to set user agent: $e');
      }
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

  // NEW: On web, chat content gets stretched edge-to-edge on wide screens
  // which is hard to read. This centers the chat column and caps its width
  // like DeepSeek/ChatGPT/Claude web UIs do. Mobile is untouched because
  // this returns the child unchanged when kIsWeb is false.
  Widget _webCentered(Widget child) {
    if (!kIsWeb) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: child,
      ),
    );
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
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.orange,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              currentModel.name,
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
                      'Clear Chat',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _clearChatHistory();
                    },
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'share',
                  child: ListTile(
                    leading: const Icon(Icons.share, color: Colors.white),
                    title: const Text(
                      'Share Chat',
                      style: TextStyle(color: Colors.indigoAccent),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _shareConversation();
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
                _clearChatHistory();
              } else if (value == 'share') {
                _shareConversation();
              } else if (_availableModels.any((m) => m.id == value)) {
                _changeModel(value);
              }
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Stack(
          children: [
            _webCentered(
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 12,
                    ),
                    color: Colors.grey.shade900,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange, width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.model_training,
                                size: 12,
                                color: Colors.blueAccent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _availableModels
                                    .firstWhere((m) => m.id == _selectedModel)
                                    .name,
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),

                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _enableThinking = !_enableThinking;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _enableThinking
                                      ? '🤔 Thinking mode ON - Thoughts hidden in dropdown'
                                      : '⚡ Fast mode ON - All text shown directly',
                                ),
                                backgroundColor:
                                    _enableThinking
                                        ? Colors.blueGrey
                                        : Colors.blue,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  _enableThinking
                                      ? Colors.brown.withAlpha(20)
                                      : Colors.blue.withAlpha(20),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    _enableThinking
                                        ? Colors.lightBlue
                                        : Colors.blue,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _enableThinking
                                      ? Icons.psychology
                                      : Icons.flash_on,
                                  size: 10,
                                  color:
                                      _enableThinking
                                          ? Colors.deepOrangeAccent
                                          : Colors.blue,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _enableThinking ? 'Thinking' : 'Fast',
                                  style: TextStyle(
                                    color:
                                        _enableThinking
                                            ? Colors.deepOrange
                                            : Colors.blue,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue, width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.thermostat,
                                size: 10,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Temp: ${_temperature.toStringAsFixed(1)}',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green, width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.memory,
                                size: 10,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Ctx: $_maxContextMessages',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        if (_enableStreaming)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  _isStreaming
                                      ? Colors.green.withAlpha(20)
                                      : Colors.grey.withAlpha(20),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    _isStreaming ? Colors.green : Colors.grey,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isStreaming
                                      ? Icons.stream
                                      : Icons.check_circle,
                                  size: 10,
                                  color:
                                      _isStreaming ? Colors.green : Colors.grey,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _isStreaming ? 'Streaming' : 'Ready',
                                  style: TextStyle(
                                    color:
                                        _isStreaming
                                            ? Colors.green
                                            : Colors.grey,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  Expanded(
                    child:
                        _messages.isEmpty && _currentStreamText.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
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
                                    'Temperature: ${_temperature.toStringAsFixed(1)} | Streaming: Enabled',
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  if (_userProfileBox.values.isEmpty)
                                    GestureDetector(
                                      onTap: _showProfileDialog,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withAlpha(30),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: Colors.green,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
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
                                            SizedBox(width: 8),
                                            Icon(
                                              Icons.arrow_forward,
                                              color: Colors.green,
                                              size: 12,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            )
                            : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.only(
                                top: 4,
                                bottom: 100,
                                left: 2,
                                right: 2,
                              ),
                              itemCount:
                                  _messages.length +
                                  (_currentStreamText.isNotEmpty ||
                                          _isThinkingPhase
                                      ? 1
                                      : 0),
                              itemBuilder: (context, index) {
                                if (index < _messages.length) {
                                  return ChatBubbleWithThinking(
                                    message: _messages[index],
                                    enableAutoScroll: _enableAutoScroll,
                                    onContinuePressed:
                                        _messages[index].isIncomplete
                                            ? _continueIncompleteResponse
                                            : null,
                                    onRetryPressed:
                                        _messages[index].canRetry
                                            ? _retryFailedRequest
                                            : null,
                                  );
                                } else {
                                  if (_isThinkingPhase && _enableThinking) {
                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 4,
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.cyan.withAlpha(20),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.cyanAccent,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.psychology,
                                            color: Colors.blueAccent,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Thinking Process',
                                                  style: TextStyle(
                                                    color: Colors.cyanAccent,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                if (_currentThinkingProcess
                                                    .isNotEmpty)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          10,
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
                                                      ),
                                                    ),
                                                  ),
                                              ],
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
                                      onContinuePressed: null,
                                      onRetryPressed: null,
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
                                    image: MemoryImage(_selectedImages[index]),
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
                                    if (_inputFocusNode?.hasFocus == false) {
                                      _inputFocusNode?.requestFocus();
                                    }
                                  },
                                ),
                              ),

                            Expanded(
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 140,
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
                                  maxLines: null, // NO MAX LINES - unlimited
                                  keyboardType: TextInputType.multiline,
                                  textInputAction: TextInputAction.newline,
                                  decoration: InputDecoration(
                                    hintText: 'Type your message...',
                                    hintStyle: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 14,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    suffixIcon:
                                        _isStreaming
                                            ? IconButton(
                                              icon: const Icon(
                                                Icons.stop,
                                                color: Colors.red,
                                                size: 18,
                                              ),
                                              onPressed: () async {
                                                await _cancelCurrentStream();
                                                if (mounted) {
                                                  setState(() {
                                                    _isSendingMessage = false;
                                                    _isStreaming = false;
                                                    _currentStreamText = '';
                                                    _currentThinkingProcess =
                                                        '';
                                                    _isThinkingComplete = false;
                                                    _isThinkingPhase = false;
                                                  });
                                                }
                                                if (_inputFocusNode?.hasFocus ==
                                                    false) {
                                                  _inputFocusNode
                                                      ?.requestFocus();
                                                }
                                              },
                                            )
                                            : null,
                                  ),
                                  onChanged: (value) {},
                                  onSubmitted: (_) {
                                    if (!_isSendingMessage) {
                                      _sendGeminiMessage();
                                    }
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(width: 6),

                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color:
                                    _isSendingMessage
                                        ? Colors.grey.shade700
                                        : Colors.lightBlue,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon:
                                    _isSendingMessage
                                        ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                        : const Icon(
                                          Icons.send,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                onPressed: () async {
                                  if (!_isSendingMessage) {
                                    await _sendGeminiMessage();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
_buildBannerAd(),
            _buildScrollToBottomButton(),
            _buildScrollProgressIndicator(), 
          ],
        ),
      ),
    );
  }

  Widget _buildWebView() {
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
    if (_showPlatformSelection) {
      return _buildPlatformSelection();
    } else if (_usingGeminiAPI) {
      return _buildGeminiAPIChat();
    } else {
      return _buildWebView();
    }
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

// COMPLETELY REWRITTEN CODE BLOCK LOGIC - NO MORE BUGS!
class _CodeBlock {
  final String language;
  final String code;

  _CodeBlock({required this.language, required this.code});
}

class ChatBubbleWithThinking extends StatefulWidget {
  final ChatMessage message;
  final bool enableAutoScroll;
  final VoidCallback? onContinuePressed;
  final VoidCallback? onRetryPressed;

  const ChatBubbleWithThinking({
    super.key,
    required this.message,
    this.enableAutoScroll = false,
    this.onContinuePressed,
    this.onRetryPressed,
  });

  @override
  State<ChatBubbleWithThinking> createState() => _ChatBubbleWithThinkingState();
}

class _ChatBubbleWithThinkingState extends State<ChatBubbleWithThinking> {
  bool _isThinkingExpanded = false;

  String _formatThinkingTime(Duration duration) {
    if (duration.inSeconds < 1) {
      return '${duration.inMilliseconds}ms';
    } else if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    } else {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    }
  }

  Widget _buildThinkingSection() {
    if (widget.message.thinkingProcess == null ||
        widget.message.thinkingProcess!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.pinkAccent.withAlpha(100), width: 1),
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
          color: Colors.tealAccent,
          size: 20,
        ),
        title: Row(
          children: [
            const Icon(Icons.psychology, size: 16, color: Colors.greenAccent),
            const SizedBox(width: 8),
            Text(
              widget.message.thinkingTime != null
                  ? 'Thought for ${_formatThinkingTime(widget.message.thinkingTime!)}'
                  : 'Thinking Process',
              style: const TextStyle(
                color: Colors.indigoAccent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!_isThinkingExpanded)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detailed Reasoning:',
                  style: TextStyle(
                    color: Colors.lightBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SelectionArea(
                    child: Text(
                      widget.message.thinkingProcess!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.4,
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

  // COMPLETELY NEW CODE BLOCK EXTRACTION - NO DUPLICATION BUG
  List<_CodeBlock> _extractCodeBlocks(String text) {
    final List<_CodeBlock> blocks = [];
    final regex = RegExp(r'```(\w*)\s*\n?([\s\S]*?)```', multiLine: true);

    for (final match in regex.allMatches(text)) {
      final language = (match.group(1) ?? '').trim();
      final code = (match.group(2) ?? '').trim();

      if (code.isNotEmpty) {
        // Check for duplicate code blocks
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

  // NEW: Build code block with language label and copy button
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
                const SizedBox(width: 8),
                Text(
                  block.language.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
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
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(50),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.content_copy,
                          size: 12,
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

  // NEW: Parse text with code blocks - NO DUPLICATION
  Widget _buildParsedText(String text) {
    final codeBlocks = _extractCodeBlocks(text);

    if (codeBlocks.isEmpty) {
      return SelectionArea(
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      );
    }

    // Split text by code blocks
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
      return Text(
        message.text,
        style: const TextStyle(color: Colors.redAccent, fontSize: 14),
      );
    } else {
      return _buildParsedText(message.text);
    }
  }

  // FIX: Copy entire message including code blocks
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
            Icon(Icons.refresh, size: 16),
            SizedBox(width: 8),
            Text('Retry'),
          ],
        ),
      ),
    );
  }

  // NEW: Action buttons at bottom of AI responses
  Widget _buildActionButtons() {
    if (widget.message.isUser || widget.message.isLoading) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          // Copy button
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

          // Regenerate button (using retry logic)
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

  @override
  Widget build(BuildContext context) {
    final message = widget.message;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 4),
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
                  color: message.isUser ? Colors.blue.shade900 : Colors.black87,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.images != null && message.images!.isNotEmpty)
                      Container(
                        margin: EdgeInsets.only(
                          bottom: message.text.isNotEmpty ? 8 : 0,
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              message.images!.asMap().entries.map((entry) {
                                return _buildImagePreview(
                                  entry.value,
                                  entry.key,
                                );
                              }).toList(),
                        ),
                      ),

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

                    // NEW: Action buttons
                    if (!message.isError) _buildActionButtons(),
                  ],
                ),
              ),
            ],
          ),
        ),
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
