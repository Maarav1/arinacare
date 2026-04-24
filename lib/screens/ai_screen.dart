import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:arina_cave/services/ad_service.dart';
import 'package:arina_cave/widgets/ad_banner.dart';
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
  bool _responseIncomplete = false;
  String _lastIncompleteResponse = '';
  bool _isContinuingResponse = false;

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

  // Thinking mode tracking
  final Stopwatch _thinkingStopwatch = Stopwatch();
  String _currentThinkingProcess = '';
  bool _isThinkingComplete = false;
  bool _isThinkingPhase = false;

  // Web search
  final bool _enableWebSearch = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeHive();
    _initializeApiKey();
    _initializeWebView();
    _initializeFocusNode();
    _scrollController = ScrollController();
    _messageController.addListener(() {});
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
    _messageController.dispose();
    _nameController.dispose();
    _interestsController.dispose();
    _inputFocusNode?.dispose();
    _scrollController.dispose();
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

    if (_geminiInitialized && kDebugMode) {
      if (kDebugMode) {
        print('✅ Gemini API Key loaded successfully');
      }
    }
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
      _responseIncomplete = false;
      _lastIncompleteResponse = '';
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
      '...',
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



  Stream<String> _streamGeminiResponse(
    String prompt, {
    List<Uint8List>? images,
  }) async* {
    const String baseUrl =
        'https://generativelanguage.googleapis.com/v1beta/models/';
    final String url =
        '$baseUrl$_selectedModel:streamGenerateContent?alt=sse&key=$_geminiApiKey';

    final headers = {'Content-Type': 'application/json'};

    final userProfiles = _userProfileBox.values.toList();
    final hasUserInfo = userProfiles.isNotEmpty;
    final userName = hasUserInfo ? userProfiles.first.name : '';
    final userInterests = hasUserInfo ? userProfiles.first.interests : '';

    final List<Map<String, dynamic>> contents = [];

    final now = DateTime.now();
    final dateFormatter = DateFormat('MMMM dd, yyyy');
    final timeFormatter = DateFormat('HH:mm');
    final currentDate = dateFormatter.format(now);
    final currentTime = timeFormatter.format(now);
    final currentYear = now.year;

    String systemPrompt =
        '''You are a helpful AI assistant having a conversation with a user.
You have memory of previous messages in this conversation.
Always remember the full conversation context.
Respond naturally and helpfully.
If asked about previous messages, reference them appropriately.

IMPORTANT: You must be aware of the current date and time.
Current Date: $currentDate
Current Time: $currentTime
Current Year: $currentYear

Use this real-time context when responding to time-sensitive questions.
If asked about current events, news, or recent developments, acknowledge the current date context.
If information might be outdated or you're unsure about recent developments, mention this limitation.''';

    if (hasUserInfo && userName.isNotEmpty) {
      systemPrompt += '\n\nThe user\'s name is $userName.';
      if (userInterests.isNotEmpty) {
        systemPrompt += ' They are interested in: $userInterests.';
      }
      systemPrompt +=
          ' Use this information to personalize responses when appropriate.';
    }

    final isTimeSensitive = _isTimeSensitiveQuery(prompt);
    if (isTimeSensitive && !_enableWebSearch) {
      systemPrompt +=
          '\n\nNote: The user is asking about time-sensitive information. Acknowledge that your knowledge has a cutoff and suggest enabling web search for the most current information if available.';
    }

    if (_enableThinking) {
      systemPrompt +=
          '\n\nIMPORTANT: When responding, first think step by step about your reasoning internally. '
          'Describe your thinking process in natural language, explaining:'
          '1. What the user is asking or requesting'
          '2. What you need to consider or analyze'
          '3. How you approach solving the problem'
          '4. What steps you take to reach a conclusion'
          '5. Any assumptions or considerations you make'
          'Use this exact format: "THINKING_START[your detailed thinking process here]THINKING_END". '
          'After finishing thinking, immediately provide your final response. '
          'The thinking section will be shown separately from the final response.';
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
              'I understand. I will remember our conversation context${hasUserInfo && userName.isNotEmpty ? ' and address you as $userName when appropriate.' : '.'} I am aware that today is $currentDate and the current year is $currentYear.${_enableThinking ? ' I will first think internally using the specified format, then provide the final response.' : ''}',
        },
      ],
    });

    final chatMessages =
        _messages.where((msg) => !msg.text.contains('I understand')).toList();
    final recentMessages =
        chatMessages.length <= 100
            ? chatMessages
            : chatMessages.sublist(chatMessages.length - 100);

    for (final msg in recentMessages) {
      contents.add({
        'role': msg.isUser ? 'user' : 'model',
        'parts': [
          {'text': msg.text},
        ],
      });
    }

    final List<Map<String, dynamic>> currentParts = [
      {'text': prompt},
    ];

    if (images != null && images.isNotEmpty) {
      for (var imageBytes in images) {
        currentParts.add({
          'inline_data': {
            'mime_type': 'image/jpeg',
            'data': base64Encode(imageBytes),
          },
        });
      }
    }

    contents.add({'role': 'user', 'parts': currentParts});

    final requestBody = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        'temperature': _temperature,
        'topK': 40,
        'topP': 0.99,
        'maxOutputTokens': 16384,
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
    };

    if (kDebugMode) {
      print(
        '🔗 Sending streaming request to Gemini API with ${recentMessages.length} previous messages',
      );
      print('📝 Prompt: $prompt');
      if (images != null && images.isNotEmpty) {
        print('🖼️ Images: ${images.length}');
      }
      print('📅 Current date context: $currentDate, Year: $currentYear');
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

  Future<void> _continueIncompleteResponse() async {
    if (_isContinuingResponse ||
        !_responseIncomplete ||
        _lastIncompleteResponse.isEmpty) {
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
        "Please continue from where you left off.",
      ).listen(
        (chunk) {
          if (!mounted) return;

          setState(() {
            accumulatedResponse += chunk;
            _currentStreamText = accumulatedResponse;
          });
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _messages.add(
              ChatMessage(
                text: 'Error continuing response: ${error.toString()}',
                isUser: false,
                timestamp: DateTime.now(),
                isError: true,
              ),
            );
            _resetContinueState();
          });
        },
        onDone: () async {
          if (!mounted) return;

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
            _responseIncomplete = false;
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
            text: 'Failed to continue response: ${e.toString()}',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
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

    setState(() {
      _isSendingMessage = true;
    });

    final String originalMessage = message;

    _messageController.clear();

    await _cancelCurrentStream();

    if (mounted) {
      setState(() {
        _selectedImages.clear();
        _isStreaming = true;
        _currentThinkingProcess = '';
        _isThinkingComplete = false;
        _isThinkingPhase = false;
        _currentStreamText = '';

        _messages.add(
          ChatMessage(
            text: originalMessage,
            isUser: true,
            timestamp: DateTime.now(),
            images: images.isNotEmpty ? List.from(images) : null,
          ),
        );
      });
    }

    _thinkingStopwatch.reset();
    _thinkingStopwatch.start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputFocusNode?.requestFocus();
    });

    try {
      String accumulatedResponse = '';
      bool thinkingDetected = false;

      _streamSubscription = _streamGeminiResponse(
        originalMessage.isEmpty ? "[Image analysis request]" : originalMessage,
        images: images.isNotEmpty ? images : null,
      ).listen(
        (chunk) {
          if (!mounted) return;

          setState(() {
            accumulatedResponse += chunk;

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
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _messages.add(
              ChatMessage(
                text: 'Error: ${error.toString()}',
                isUser: false,
                timestamp: DateTime.now(),
                isError: true,
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
              _responseIncomplete = true;
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
          });

          await _saveConversation();

          final aiResponses =
              _messages.where((m) => !m.isUser && !m.isError).length;
          if (aiResponses % 3 == 0) {
            AdService.instance.showInterstitialAd();
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Failed to get response: ${e.toString()}',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
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
        _responseIncomplete = false;
        _lastIncompleteResponse = '';
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildScrollToBottomButton() {
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
                color: Colors.black.withAlpha(50),
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
          _responseIncomplete = false;
          _lastIncompleteResponse = '';
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
          _responseIncomplete = false;
          _lastIncompleteResponse = '';
          _isLoading = true;
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
              maxLines: 5,
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
          _responseIncomplete = false;
          _lastIncompleteResponse = '';
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
          SnackBar(
            content: const Text('Failed to clear chat history'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
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

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
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

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller;
    _setUserAgent();
  }

  void _applyAccuracySettings(String url) {
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

    _controller.runJavaScript(jsCode);
  }

  void _setUserAgent() async {
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
            Column(
              children: [
                // Header bar with model info
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
                              color: _isStreaming ? Colors.green : Colors.grey,
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
                                      _isStreaming ? Colors.green : Colors.grey,
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

                // Chat messages area
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
                                  'Temperature: ${_temperature.toStringAsFixed(1)} (High Accuracy)',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Streaming: Enabled',
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
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.green),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.person_add,
                                            color: Colors.green,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Set up your profile',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
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
                                      _continueIncompleteResponse,
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
                                                  padding: const EdgeInsets.all(
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
                                    onContinuePressed:
                                        _continueIncompleteResponse,
                                  );
                                }
                              }
                            },
                          ),
                ),

                // Selected images preview
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

                // Input field at the bottom
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
                              constraints: const BoxConstraints(maxHeight: 140),
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
                                maxLines: null,
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
                                                  _currentThinkingProcess = '';
                                                  _isThinkingComplete = false;
                                                  _isThinkingPhase = false;
                                                });
                                              }
                                              if (_inputFocusNode?.hasFocus ==
                                                  false) {
                                                _inputFocusNode?.requestFocus();
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
                                await _sendGeminiMessage();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildBannerAd(),
              ],
            ),

            // Scroll to bottom button
            if (_scrollController.hasClients &&
                _scrollController.offset <
                    _scrollController.position.maxScrollExtent - 100)
              _buildScrollToBottomButton(),
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

  Widget _buildBannerAd() {
    return const AdBanner();
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
  });
}

class _CodeBlock {
  final String language;
  final String code;
  final int startIndex;
  final int endIndex;

  _CodeBlock({
    required this.language,
    required this.code,
    required this.startIndex,
    required this.endIndex,
  });
}

class ChatBubbleWithThinking extends StatefulWidget {
  final ChatMessage message;
  final bool enableAutoScroll;
  final VoidCallback? onContinuePressed;

  const ChatBubbleWithThinking({
    super.key,
    required this.message,
    this.enableAutoScroll = false,
    this.onContinuePressed,
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

  List<_CodeBlock> _extractCodeBlocks(String text) {
    final List<_CodeBlock> blocks = [];
    final regex = RegExp(r'```(\w*)\n([\s\S]*?)\n```');
    final matches = regex.allMatches(text);

    for (final match in matches) {
      final language = match.group(1) ?? '';
      final code = match.group(2) ?? '';
      blocks.add(
        _CodeBlock(
          language: language.isEmpty ? 'text' : language,
          code: code,
          startIndex: match.start,
          endIndex: match.end,
        ),
      );
    }

    return blocks;
  }

  String _replaceCodeBlocksWithMarkers(String text) {
    var result = text;
    final blocks = _extractCodeBlocks(text);

    for (final block in blocks.reversed) {
      result = result.replaceRange(
        block.startIndex,
        block.endIndex,
        '[[CODE_BLOCK_${blocks.indexOf(block)}]]',
      );
    }

    return result;
  }

  Widget _buildCodeBlock(_CodeBlock block) {
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
                Icon(Icons.code, size: 16, color: Colors.greenAccent),
                const SizedBox(width: 8),
                Text(
                  block.language.isNotEmpty
                      ? block.language.toUpperCase()
                      : 'CODE',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: block.code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Copied ${block.language} code to clipboard',
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(50),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.content_copy,
                          size: 14,
                          color: Colors.greenAccent,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Copy',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 11,
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

  Widget _buildParsedText(String text) {
    final codeBlocks = _extractCodeBlocks(text);
    final textWithMarkers = _replaceCodeBlocksWithMarkers(text);
    final parts = textWithMarkers.split(RegExp(r'\[\[CODE_BLOCK_(\d+)\]\]'));

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            parts.asMap().entries.map((entry) {
              final index = entry.key;
              final part = entry.value;

              if (index % 2 == 0) {
                if (part.trim().isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      part,
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }
                return const SizedBox.shrink();
              } else {
                final blockIndex = int.tryParse(part) ?? 0;
                if (blockIndex < codeBlocks.length) {
                  final block = codeBlocks[blockIndex];
                  return _buildCodeBlock(block);
                }
                return const SizedBox.shrink();
              }
            }).toList(),
      ),
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
        style: const TextStyle(color: Colors.redAccent),
      );
    } else {
      return _buildParsedText(message.text);
    }
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
            Text('Continue Response'),
          ],
        ),
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
                            : Colors.grey.shade700,
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

                    if (message.isIncomplete &&
                        !message.isUser &&
                        widget.onContinuePressed != null)
                      _buildContinueButton(),
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

