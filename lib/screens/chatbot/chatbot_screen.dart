import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:ui';

import '../../models/chatbot_models.dart';
import 'widgets/message_bubble.dart';
import 'widgets/chat_input_field.dart';
import 'widgets/history_drawer.dart';
import 'widgets/animated_orb.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _selectedFileName;
  XFile? _selectedImage;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _loading = false;
  final List<ChatMessage> _messages = [];
  final List<ChatSession> _chatHistory = [];
  String _currentChatTitle = 'New Chat';

  static const String _storageKey = 'chat_history_v1';

  static final String baseUrl = (() {
    final raw = dotenv.env['HF_SPACE_URL']?.trim() ?? '';
    if (raw.isEmpty) return 'http://127.0.0.1:8000';
    var clean = raw.replaceAll(RegExp(r'/health$'), '');
    clean = clean.replaceAll(RegExp(r'/detect$'), '');
    clean = clean.replaceAll(RegExp(r'/embed$'), '');
    clean = clean.replaceAll(RegExp(r'/recipe-agent$'), '');
    clean = clean.replaceAll(RegExp(r'/$'), '');
    return clean.isEmpty ? 'http://127.0.0.1:8000' : clean;
  })();

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;

      final List<dynamic> decoded = jsonDecode(raw);
      final restored = decoded.map((entry) {
        final data = entry as Map<String, dynamic>;
        final messages = (data['messages'] as List<dynamic>).map((messageData) {
          final map = messageData as Map<String, dynamic>;
          return ChatMessage(
            isUser: map['isUser'] as bool,
            text: map['text'] as String?,
            recipe: map['recipe'] == null
                ? null
                : Map<String, dynamic>.from(map['recipe'] as Map),
            timestamp: map['timestamp'] == null
                ? null
                : DateTime.tryParse(map['timestamp'] as String),
          );
        }).toList();

        return ChatSession(title: data['title'] as String, messages: messages);
      }).toList();

      setState(() {
        _chatHistory.clear();
        _chatHistory.addAll(restored);
      });
    } catch (e) {
      debugPrint('[ChatbotScreen] load history error: $e');
    }
  }

  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(
        _chatHistory.map((session) {
          return {
            'title': session.title,
            'messages': session.messages.map((message) {
              return {
                'isUser': message.isUser,
                'text': message.text,
                'recipe': message.recipe,
                'timestamp': message.timestamp.toIso8601String(),
              };
            }).toList(),
          };
        }).toList(),
      );
      await prefs.setString(_storageKey, raw);
    } catch (e) {
      debugPrint('[ChatbotScreen] save history error: $e');
    }
  }

  void _startNewChat() {
    setState(() {
      _messages.clear();
      _currentChatTitle = 'New Chat';
    });
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.pop(context);
    }
  }

  void _openChatSession(ChatSession session) {
    setState(() {
      _messages.clear();
      _messages.addAll(session.messages);
      _currentChatTitle = session.title;
    });
    Navigator.pop(context);
  }

  void _saveCurrentChat() {
    if (_messages.isEmpty) return;

    final title = _currentChatTitle == 'New Chat'
        ? (_messages.first.text ?? 'New Chat')
        : _currentChatTitle;
    setState(() {
      _chatHistory.removeWhere((chat) => chat.title == title);

      _chatHistory.insert(
        0,
        ChatSession(title: title, messages: List<ChatMessage>.from(_messages)),
      );
    });

    _saveChatHistory();
  }

  Future<void> _sendMessage() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty || _loading) return;

    setState(() {
      _messages.add(ChatMessage(isUser: true, text: prompt));

      if (_messages.length == 1) {
        _currentChatTitle = prompt;
      }

      _loading = true;
    });

    _saveCurrentChat();
    _controller.clear();
    _scrollToBottom();

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/recipe-agent'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'dish': prompt, 'servings': 2}),
          )
          .timeout(const Duration(seconds: 10));

      dynamic data;
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        data = null;
      }

      if (response.statusCode == 200 && data is Map<String, dynamic>) {
        if (data['status'] == 'success') {
          setState(() {
            _messages.add(ChatMessage(isUser: false, recipe: data));
          });
        } else {
          setState(() {
            _messages.add(
              ChatMessage(
                isUser: false,
                text: data['message'] ?? 'Recipe not found',
              ),
            );
          });
        }
      } else {
        setState(() {
          _messages.add(
            ChatMessage(
              isUser: false,
              text: 'Server error: ${response.statusCode}',
            ),
          );
        });
      }

      _saveCurrentChat();
    } on TimeoutException {
      setState(() {
        _messages.add(
          ChatMessage(
            isUser: false,
            text: 'Request timed out. Please try again.',
          ),
        );
      });

      _saveCurrentChat();
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            isUser: false,
            text: 'Unable to connect to recipe service.',
          ),
        );
      });

      _saveCurrentChat();
    } finally {
      setState(() {
        _loading = false;
      });

      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFE8F1F2),
      drawer: HistoryDrawer(
        chatHistory: _chatHistory,
        onStartNewChat: _startNewChat,
        onOpenChatSession: _openChatSession,
      ),
      body: Stack(
        children: [
          // Colorful glowing gradient bubbles (Orbs)
          Positioned(
            top: 20,
            right: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF001A23).withOpacity(0.08),
                    const Color(0xFF001A23).withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -40,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFB3EFB2).withOpacity(0.15),
                    const Color(0xFFB3EFB2).withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(color: Colors.transparent),
            ),
          ),
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Floating Header Pill
                ChatHeaderPill(
                  onHistoryTap: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                  onNewChatTap: () {
                    _startNewChat();
                  },
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _messages.isEmpty
                      ? SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const WelcomeCard(),
                              const Padding(
                                padding: EdgeInsets.fromLTRB(24, 16, 24, 12),
                                child: Text(
                                  'Try asking me',
                                  style: TextStyle(
                                    fontFamily: 'ClashDisplay',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF001A23),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Column(
                                  children: [
                                    SuggestionPill(
                                      text: 'Suggest healthy breakfast items to buy',
                                      icon: Icons.shopping_basket_outlined,
                                      onTap: () {
                                        _controller.text = 'Suggest healthy breakfast items to buy';
                                        _sendMessage();
                                      },
                                    ),
                                    SuggestionPill(
                                      text: 'Add milk, organic eggs and bread to my cart',
                                      icon: Icons.add_shopping_cart_rounded,
                                      onTap: () {
                                        _controller.text = 'Add milk, organic eggs and bread to my cart';
                                        _sendMessage();
                                      },
                                    ),
                                    SuggestionPill(
                                      text: 'Is organic milk healthier than regular milk?',
                                      icon: Icons.help_outline_rounded,
                                      onTap: () {
                                        _controller.text = 'Is organic milk healthier than regular milk?';
                                        _sendMessage();
                                      },
                                    ),
                                    SuggestionPill(
                                      text: 'Quick and easy dinner recipe ideas',
                                      icon: Icons.restaurant_menu_rounded,
                                      onTap: () {
                                        _controller.text = 'Quick and easy dinner recipe ideas';
                                        _sendMessage();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: _messages.length,
                          itemBuilder: (_, index) =>
                              MessageBubble(message: _messages[index]),
                        ),
                ),
                if (_loading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: MessageBubble(
                      message: ChatMessage(
                        isUser: false,
                        text: null, // trigger typing indicator
                      ),
                    ),
                  ),
                ChatInputField(
                  controller: _controller,
                  loading: _loading,
                  onSend: _sendMessage,
                  selectedImage: _selectedImage,
                  selectedFileName: _selectedFileName,
                  onImageSelected: (image) {
                    setState(() {
                      _selectedImage = image;
                    });
                  },
                  onFileSelected: (file, fileName) {
                    setState(() {
                      _selectedFileName = fileName;
                    });
                  },
                  onClearImage: () {
                    setState(() {
                      _selectedImage = null;
                    });
                  },
                  onClearFile: () {
                    setState(() {
                      _selectedFileName = null;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatHeaderPill extends StatelessWidget {
  final VoidCallback onHistoryTap;
  final VoidCallback onNewChatTap;

  const ChatHeaderPill({
    super.key,
    required this.onHistoryTap,
    required this.onNewChatTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFD2E4E6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF001A23).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left actions: History
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: onHistoryTap,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: const Color(0xFFD2E4E6),
                    width: 1.2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.history_rounded,
                    color: Color(0xFF001A23),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          // Center Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 104),
            child: Text(
              'Qless Assistant',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'ClashDisplay',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF001A23),
              ),
            ),
          ),
          // Right action: New Chat (+)
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onNewChatTap,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: const Color(0xFFD2E4E6),
                    width: 1.2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.add_comment_outlined,
                    color: Color(0xFF001A23),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WelcomeCard extends StatelessWidget {
  const WelcomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: LinearGradient(
          colors: [
            Colors.white,
            const Color(0xFFB3EFB2).withValues(alpha: 0.08),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0xFFD2E4E6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF001A23).withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: ClipOval(child: AnimatedOrb(size: 64)),
              ),
              SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Hi there!',
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF001A23),
                      ),
                    ),
                    Text(
                      'I\'m your Qless Assistant.',
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF001A23),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Ask me questions, get item suggestions, update your cart, or find recipe ideas!',
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF001A23).withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class SuggestionPill extends StatefulWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  const SuggestionPill({
    super.key,
    required this.text,
    required this.icon,
    required this.onTap,
  });

  @override
  State<SuggestionPill> createState() => _SuggestionPillState();
}

class _SuggestionPillState extends State<SuggestionPill> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 76,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFD2E4E6), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF001A23,
                ).withOpacity(_isPressed ? 0.03 : 0.05),
                blurRadius: 16,
                offset: _isPressed ? const Offset(0, 4) : const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFB3EFB2).withOpacity(0.2),
                ),
                child: Icon(
                  widget.icon,
                  color: const Color(0xFF001A23),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.text,
                  style: const TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF001A23),
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Color(0xFF001A23),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
