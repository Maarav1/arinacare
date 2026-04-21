import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AScreen extends StatefulWidget {
  const AScreen({super.key});

  @override
  State<AScreen> createState() => _AScreenState();
}

class _AScreenState extends State<AScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _showPlatformSelection = true;
  bool _usingGeminiAPI = false;

  // AdMob variables
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  // Gemini API variables
  late final String _geminiApiKey;
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _geminiInitialized = false;
  bool _isSendingMessage = false;
  
  // Streaming variables
  String _currentStreamText = '';
  StreamSubscription<String>? _streamSubscription;
  bool _isStreaming = false;
  late ScrollController _scrollController;

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
      id: 'gemini-2.5-pro',
      name: 'Gemini 2.5 Pro', 
      description: 'Complex reasoning',
      priority: 'High Reasoning',
      bestFor: 'Advanced tasks',
      isRecommended: false,
    ),
    GeminiModel(
      id: 'gemini-2.5-flash-latest',
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
    ),
    AIPlatform(
      name: 'Gemini',
      url: 'gemini://api',
      icon: Icons.auto_awesome,
      color: Colors.orange,
    ),
    AIPlatform(
      name: 'Gemini Web',
      url: 'https://gemini.google.com/',
      icon: Icons.language,
      color: Colors.blue,
    ),
    AIPlatform(
      name: 'reka',
      url: 'https://reka.ai/',
      icon: Icons.search,
      color: Colors.white,
    ),
    AIPlatform(
      name: 'Claude',
      url: 'https://claude.ai/',
      icon: Icons.face,
      color: Colors.purple,
    ),
    AIPlatform(
      name: 'DeepSeek',
      url: 'https://chat.deepseek.com/',
      icon: Icons.psychology,
      color: Colors.blue,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeApiKey();
    _initializeWebView();
    _initializeAds();
    _initializeGeminiAPI();
    _startInterstitialTimer();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _bannerAd?.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeApiKey() {
    _geminiApiKey = dotenv.get('GEMINI_API_KEY', fallback: '');
    
    if (_geminiApiKey.isEmpty) {
      _geminiInitialized = false;
      if (kDebugMode) {
        print('Warning: Gemini API key not found');
      }
    } else {
      _geminiInitialized = true;
      if (kDebugMode) {
        print('✅ Gemini API key loaded');
      }
    }
  }

  void _initializeGeminiAPI() {
    // No need to initialize google_generative_ai model anymore
    // Just check if API key exists
    if (_geminiApiKey.isNotEmpty) {
      _geminiInitialized = true;
      if (kDebugMode) {
        print('✅ Gemini API ready for streaming with model: $_selectedModel');
      }
    }
  }

  void _changeModel(String newModel) {
    setState(() {
      _selectedModel = newModel;
      _messages.clear();
      _currentStreamText = '';
    });
  }

  // STREAMING METHOD - UPDATED TO WORK WITH GEMINI API
Stream<String> _streamGeminiResponse(String prompt) async* {
  const String baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/';
  final String url = '$baseUrl$_selectedModel:streamGenerateContent?alt=sse&key=$_geminiApiKey';
  
  final headers = {
    'Content-Type': 'application/json',
  };
  
  // Prepare the request body - CORRECTED FOR GEMINI API
  final body = jsonEncode({
    'contents': [
      {
        'parts': [
          {'text': prompt}
        ]
      }
    ],
    'generationConfig': {
      'temperature': 0.2,
      'topK': 40,
      'topP': 0.95,
      'maxOutputTokens': 32768, // Set a high value instead of 8192
    }
  });
  
  if (kDebugMode) {
    print('🔗 Sending streaming request to Gemini API');
    print('📝 Prompt: $prompt');
  }
  
  try {
    final request = http.Request('POST', Uri.parse(url));
    request.headers.addAll(headers);
    request.body = body;
    
    final streamedResponse = await request.send();
    
    if (streamedResponse.statusCode != 200) {
      throw Exception('API request failed with status ${streamedResponse.statusCode}');
    }
    
    await for (final chunk in streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      
      if (chunk.trim().isEmpty) continue;
      
      if (kDebugMode) {
        print('📦 Received chunk: $chunk');
      }
      
      if (chunk.startsWith('data: ')) {
        final jsonString = chunk.substring(6); // Remove 'data: ' prefix
        
        if (jsonString == '[DONE]') {
          if (kDebugMode) {
            print('✅ Streaming complete');
          }
          break;
        }
        
        try {
          final jsonData = jsonDecode(jsonString);
          
          // Parse the response according to Gemini API format
          if (jsonData['candidates'] != null && jsonData['candidates'].isNotEmpty) {
            final candidate = jsonData['candidates'][0];
            if (candidate['content'] != null && candidate['content']['parts'] != null) {
              final parts = candidate['content']['parts'];
              if (parts.isNotEmpty && parts[0]['text'] != null) {
                final text = parts[0]['text'] as String;
                if (text.isNotEmpty) {
                  if (kDebugMode) {
                    print('📝 Text chunk: $text');
                  }
                  yield text; // Stream each chunk
                }
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ JSON parsing error: $e for chunk: $chunk');
          }
          // Try to extract any error message
          if (jsonString.contains('error')) {
            try {
              final errorJson = jsonDecode(jsonString);
              if (errorJson['error'] != null && errorJson['error']['message'] != null) {
                throw Exception('API Error: ${errorJson['error']['message']}');
              }
            } catch (_) {
              // Ignore parsing errors for error messages
            }
          }
        }
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ Stream request error: $e');
      print('🔗 URL was: $baseUrl$_selectedModel:streamGenerateContent?alt=sse&key=...');
    }
    rethrow;
  }
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
            // Update loading bar.
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _applyAccuracySettings(url);
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
            });
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
        if (window.location.href.includes('gemini.google.com')) {
          console.log('Gemini accuracy settings applied');
        }
        
        if (window.location.href.includes('chat.openai.com')) {
          setTimeout(() => {
            const preciseElements = document.querySelectorAll('[class*="precise"], [class*="accurate"], [class*="temperature"]');
            preciseElements.forEach(el => {
              if (el.textContent?.toLowerCase().includes('precise') || 
                  el.textContent?.toLowerCase().includes('accurate')) {
                el.click();
                console.log('Precision mode activated');
              }
            });
          }, 2000);
        }
        
        document.body.style.backgroundColor = '#000000';
        document.body.style.color = '#ffffff';
      }
      
      setAccuracySettings();
      
      const observer = new MutationObserver(setAccuracySettings);
      observer.observe(document.body, {
        childList: true,
        subtree: true
      });
    """;
    
    _controller.runJavaScript(jsCode);
  }

  void _setUserAgent() async {
    const desktopUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
    
    try {
      await _controller.setUserAgent(desktopUserAgent);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to set user agent: $e');
      }
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
          if (kDebugMode) {
            print('Banner ad loaded successfully');
          }
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          if (kDebugMode) {
            print('Banner ad failed to load: $error');
          }
          ad.dispose();
          Future.delayed(const Duration(seconds: 10), () {
            if (mounted) {
              _initializeAds();
            }
          });
        },
      ),
    );
    _bannerAd?.load();
  }

  void _startInterstitialTimer() {
    Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted && _usingGeminiAPI) {
        AdManager.showInterstitialAd();
      }
    });
    
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        AdManager.showInterstitialAd();
      }
    });
  }

  void _loadUrl(String url) {
    if (url == 'gemini://api') {
      if (!_geminiInitialized || _geminiApiKey.isEmpty) {
        _showApiErrorDialog();
        return;
      }
      
      setState(() {
        _showPlatformSelection = false;
        _usingGeminiAPI = true;
        //_messages.clear();
        _currentStreamText = '';
      });
    } else {
      setState(() {
        _showPlatformSelection = false;
        _usingGeminiAPI = false;
        _currentStreamText = '';
        _isLoading = true;
      });
      _controller.loadRequest(Uri.parse(url));
    }
  }

  void _showApiErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gemini API Not Available'),
        content: const Text('Gemini API is not configured properly. Please check your API key configuration.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendGeminiMessage() async {
  if (_messageController.text.trim().isEmpty || _isSendingMessage) return;
  
  // Cancel any existing stream
  await _cancelCurrentStream();
  
  setState(() {
    _isSendingMessage = true;
    _isStreaming = true;
  });

  if (!_geminiInitialized) {
    setState(() {
      _messages.add(ChatMessage(
        text: 'Gemini API is not available. Please check your API key configuration.',
        isUser: false,
        timestamp: DateTime.now(),
        isError: true,
      ));
      _isSendingMessage = false;
      _isStreaming = false;
    });
    return;
  }

  final String message = _messageController.text.trim();
  _messageController.clear();

  // Add user message
  setState(() {
    _messages.add(ChatMessage(
      text: message,
      isUser: true,
      timestamp: DateTime.now(),
    ));
    _currentStreamText = ''; // Reset streaming text
  });

   WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  });

  try {
    String fullResponse = '';
    
    if (kDebugMode) {
      print('🚀 Starting Gemini streaming for: "$message"');
    }
    
    // Start streaming
    _streamSubscription = _streamGeminiResponse(message).listen(
      (chunk) {
        if (!mounted) return;
        
        setState(() {
          fullResponse += chunk;
          _currentStreamText = fullResponse;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
            );
          }
        });
        
        if (kDebugMode) {
          print('➕ Added chunk, total length: ${fullResponse.length}');
        }
      },
      onError: (error) {
        if (!mounted) return;
        
        if (kDebugMode) {
          print('❌ Streaming error: $error');
        }
        
        setState(() {
          _messages.add(ChatMessage(
            text: 'Error: ${error.toString()}',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ));
          _currentStreamText = '';
          _isSendingMessage = false;
          _isStreaming = false;
        });
      },
      onDone: () {
        if (!mounted) return;
        
        if (kDebugMode) {
          print('✅ Streaming completed. Total response: ${fullResponse.length} chars');
        }
        
        setState(() {
          // Add the completed message to chat history
          if (fullResponse.isNotEmpty) {
            _messages.add(ChatMessage(
              text: fullResponse,
              isUser: false,
              timestamp: DateTime.now(),
            ));
            if (kDebugMode) {
              print('📝 Added final message to history');
            }
          } else {
            _messages.add(ChatMessage(
              text: 'No response received from Gemini.',
              isUser: false,
              timestamp: DateTime.now(),
              isError: true,
            ));
          }
          _currentStreamText = '';
          _isSendingMessage = false;
          _isStreaming = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });

        // Show interstitial ad after every 3 messages
        if (_messages.where((m) => !m.isUser && !m.isError).length % 3 == 0) {
          AdManager.showInterstitialAd();
        }
      },
    );

  } catch (e) {
    if (kDebugMode) {
      print('💥 Critical error in send message: $e');
    }
    
    setState(() {
      _messages.add(ChatMessage(
        text: 'Failed to get response: ${e.toString()}',
        isUser: false,
        timestamp: DateTime.now(),
        isError: true,
      ));
      _currentStreamText = '';
      _isSendingMessage = false;
      _isStreaming = false;
    });
  }
}

  Future<void> _cancelCurrentStream() async {
    await _streamSubscription?.cancel();
    _streamSubscription = null;
  }

  void _showPlatformSelectionScreen() async {
    await _cancelCurrentStream();
    setState(() {
      _showPlatformSelection = true;
      _usingGeminiAPI = false;
      _currentStreamText = '';
      _isStreaming = false;
    });
  }

  Widget _buildPlatformSelection() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Choose AI Platform'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
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
                  color: Colors.grey[900],
                  elevation: 4,
                  child: InkWell(
                    onTap: () => _loadUrl(platform.url),
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          platform.icon,
                          size: 40,
                          color: platform.color,
                        ),
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
                        if (platform.name == 'Gemini')
                          const Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            child: Text(
                              'API Mode',
                              style: TextStyle(
                                color: Colors.green,
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
    final currentModel = _availableModels.firstWhere(
      (model) => model.id == _selectedModel,
      orElse: () => _availableModels.first,
    );

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
          PopupMenuButton<GeminiModel>(
            icon: const Icon(Icons.model_training),
            onSelected: (model) => _changeModel(model.id),
            itemBuilder: (BuildContext context) {
              return _availableModels.map((GeminiModel model) {
                return PopupMenuItem<GeminiModel>(
                  value: model,
                  child: Row(
                    children: [
                      Icon(
                        _selectedModel == model.id 
                            ? Icons.radio_button_checked 
                            : Icons.radio_button_off,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              model.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: model.isRecommended ? Colors.orange : Colors.white,
                              ),
                            ),
                            Text(
                              model.description,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                            if (model.isRecommended)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                margin: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'RECOMMENDED',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.grey[900],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.model_training, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'Model: ${currentModel.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (currentModel.isRecommended) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'RECOMMENDED',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${currentModel.description} • Temp: 0.2 • Streaming: ${_isStreaming ? 'ON' : 'OFF'}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _messages.isEmpty && _currentStreamText.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 64,
                          color: Colors.orange,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Welcome to Gemini AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Ask me anything!',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Temperature: 0.2 (High Accuracy)',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Streaming: Enabled',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                  controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_currentStreamText.isNotEmpty ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < _messages.length) {
                        return ChatBubble(message: _messages[index]);
                      } else {
                        // Show streaming message
                        return ChatBubble(
                          message: ChatMessage(
                            text: _currentStreamText,
                            isUser: false,
                            timestamp: DateTime.now(),
                            isLoading: _isStreaming,
                          ),
                        );
                      }
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[900],
            child: Row(
              children: [
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 50,
                      maxHeight: 150,
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: null,
                      expands: false,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[800],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        suffixIcon: _isStreaming
                            ? IconButton(
                                icon: const Icon(Icons.stop, color: Colors.red),
                                onPressed: () async {
                                  await _cancelCurrentStream();
                                  setState(() {
                                    _isSendingMessage = false;
                                    _isStreaming = false;
                                    _currentStreamText = '';
                                  });
                                },
                              )
                            : null,
                      ),
                      onSubmitted: (_) => _sendGeminiMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _isSendingMessage ? Colors.grey : Colors.orange,
                  child: _isSendingMessage
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: _sendGeminiMessage,
                        ),
                ),
              ],
            ),
          ),
          _buildBannerAd(),
        ],
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
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
          _buildBannerAd(),
        ],
      ),
    );
  }

  Widget _buildBannerAd() {
    if (!_isBannerAdLoaded) {
      return Container(
        height: 60,
        width: double.infinity,
        color: Colors.black,
        child: const Center(
          child: Text(
            'Loading...',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }
    
    return Container(
      height: _bannerAd?.size.height.toDouble() ?? 60,
      width: double.infinity,
      color: Colors.black,
      alignment: Alignment.center,
      child: AdWidget(ad: _bannerAd!),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showPlatformSelection) {
      return _buildPlatformSelection();
    } else if (_usingGeminiAPI) {
      return _buildGeminiAPIChat();
    } else {
      return _buildWebView();
    }
  }
}

// Gemini Model class
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

// Chat message model
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isLoading;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isLoading = false,
    this.isError = false,
  });
}

// Chat bubble widget - NOW WITH TEXT SELECTION
class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.isUser) const Spacer(),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.95,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: message.isUser
                  ? Colors.orange
                  : message.isError
                      ? Colors.red[900]
                      : Colors.grey[800],
              borderRadius: BorderRadius.circular(16),
            ),
            child: message.isLoading
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.text.isNotEmpty) ...[
                        SelectionArea(
                          child: Text(
                            message.text,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
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
                        const Text(
                          'Thinking...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ],
                  )
                : SelectionArea(
                    child: Text(
                      message.text,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
          ),
          if (!message.isUser) const Spacer(),
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

  const AIPlatform({
    required this.name,
    required this.url,
    required this.icon,
    required this.color,
  });
}

class AdManager {
  static BannerAd? _bannerAd;
  static InterstitialAd? _interstitialAd;
  static bool _isBannerAdLoaded = false;
  static bool _isInterstitialAdLoaded = false;
  static bool _isInterstitialLoading = false;

  static void initialize() {
    loadBannerAd();
    loadInterstitialAd();
  }

  static void loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-1472609237394607/8084106825',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          _isBannerAdLoaded = true;
          if (kDebugMode) {
            print('Banner ad loaded successfully');
          }
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          _isBannerAdLoaded = false;
          if (kDebugMode) {
            print('Banner ad failed to load: $error');
          }
          ad.dispose();
          Future.delayed(const Duration(seconds: 3), loadBannerAd);
        },
      ),
    )..load();
  }

  static void loadInterstitialAd() {
    if (_isInterstitialLoading) return;
    
    _isInterstitialLoading = true;
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-1472609237394607/5863485201',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoaded = true;
          _isInterstitialLoading = false;
          
          if (kDebugMode) {
            print('Interstitial ad loaded successfully');
          }
        },
        onAdFailedToLoad: (LoadAdError error) {
          _isInterstitialAdLoaded = false;
          _isInterstitialLoading = false;
          if (kDebugMode) {
            print('Interstitial ad failed to load: $error');
          }
          Future.delayed(const Duration(seconds: 5), loadInterstitialAd);
        },
      ),
    );
  }

  static void showInterstitialAd() {
    if (_isInterstitialAdLoaded && _interstitialAd != null) {
      _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          ad.dispose();
          _isInterstitialAdLoaded = false;
          loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          ad.dispose();
          _isInterstitialAdLoaded = false;
          loadInterstitialAd();
        },
      );
      
      _interstitialAd?.show();
      _interstitialAd = null;
    } else {
      loadInterstitialAd();
    }
  }

  static Widget getBannerAdWidget() {
    if (_isBannerAdLoaded && _bannerAd != null) {
      return Container(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        color: Colors.black,
        alignment: Alignment.center,
        child: AdWidget(ad: _bannerAd!),
      );
    } else {
      if (!_isBannerAdLoaded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          loadBannerAd();
        });
      }
      return _buildAdPlaceholder();
    }
  }

  static Widget _buildAdPlaceholder() {
    return Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: const Center(
        child: Text(
          'Welcome to ArinaCave',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white54,
          ),
        ),
    ));
  }

  static void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
  }
}

class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-1472609237394607/8084106825',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _isBannerAdReady = false;
          Future.delayed(const Duration(seconds: 30), _loadBannerAd);
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      width: double.infinity,
      color: Colors.black,
      alignment: Alignment.center,
      child: _isBannerAdReady && _bannerAd != null
          ? AdWidget(ad: _bannerAd!)
          : _buildAdPlaceholder(),
    );
  }

  Widget _buildAdPlaceholder() {
    return Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: const Center(
        child: Text(
          'Welcome to ArinaCave',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}