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
import '../../services/recipe_agent_service.dart';
import '../../services/cart_service.dart';

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
  String? _currentChatSessionId;

  Animation<double>? _routeAnimation;
  bool _isTransitioning = true;

  static const String _storageKey = 'chat_history_v2'; // Changed key to differentiate updated model storage

  @override
  void initState() {
    super.initState();
    _currentChatSessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    _loadChatHistory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route.animation != null) {
      if (_routeAnimation != route.animation) {
        _routeAnimation?.removeStatusListener(_handleRouteStatus);
        _routeAnimation = route.animation;
        _routeAnimation!.addStatusListener(_handleRouteStatus);
      }
      _isTransitioning = _routeAnimation!.status != AnimationStatus.completed;
    } else {
      _isTransitioning = false;
    }
  }

  void _handleRouteStatus(AnimationStatus status) {
    final transitioning = status != AnimationStatus.completed;
    if (transitioning != _isTransitioning) {
      if (mounted) {
        setState(() {
          _isTransitioning = transitioning;
        });
      }
    }
  }

  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var raw = prefs.getString(_storageKey);
      
      // Fallback to old storage key if new storage key doesn't exist yet
      if (raw == null || raw.isEmpty) {
        raw = prefs.getString('chat_history_v1');
      }
      
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

        final title = data['title'] as String? ?? 'New Chat';
        final id = data['id'] as String? ?? 'session_${DateTime.now().microsecondsSinceEpoch}_${title.hashCode}';
        
        final lastActiveStr = data['lastActive'] as String?;
        final lastActive = lastActiveStr != null
            ? (DateTime.tryParse(lastActiveStr) ?? DateTime.now())
            : (messages.isNotEmpty ? messages.last.timestamp : DateTime.now());

        return ChatSession(
          id: id,
          title: title,
          messages: messages,
          lastActive: lastActive,
        );
      }).toList();

      // Sort by lastActive descending
      restored.sort((a, b) => b.lastActive.compareTo(a.lastActive));

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
            'id': session.id,
            'title': session.title,
            'lastActive': session.lastActive.toIso8601String(),
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
      _currentChatSessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
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
      _currentChatSessionId = session.id;
    });
    Navigator.pop(context);
  }

  void _deleteChatSession(ChatSession session) {
    setState(() {
      _chatHistory.removeWhere((chat) => chat.id == session.id);
      if (_currentChatSessionId == session.id) {
        _messages.clear();
        _currentChatTitle = 'New Chat';
        _currentChatSessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      }
    });
    _saveChatHistory();
  }

  void _renameChatSession(ChatSession session, String newTitle) {
    if (newTitle.trim().isEmpty) return;
    setState(() {
      final index = _chatHistory.indexWhere((chat) => chat.id == session.id);
      if (index != -1) {
        final existing = _chatHistory[index];
        _chatHistory[index] = ChatSession(
          id: existing.id,
          title: newTitle.trim(),
          messages: existing.messages,
          lastActive: existing.lastActive,
        );
      }
      if (_currentChatSessionId == session.id) {
        _currentChatTitle = newTitle.trim();
      }
    });
    _saveChatHistory();
  }

  void _saveCurrentChat() {
    if (_messages.isEmpty) return;

    final title = _currentChatTitle == 'New Chat'
        ? (_messages.first.text ?? 'New Chat')
        : _currentChatTitle;

    setState(() {
      if (_currentChatSessionId != null) {
        final index = _chatHistory.indexWhere((chat) => chat.id == _currentChatSessionId);
        final updatedSession = ChatSession(
          id: _currentChatSessionId!,
          title: title,
          messages: List<ChatMessage>.from(_messages),
          lastActive: DateTime.now(),
        );
        if (index != -1) {
          _chatHistory.removeAt(index);
        }
        _chatHistory.insert(0, updatedSession);
      } else {
        final newId = 'session_${DateTime.now().millisecondsSinceEpoch}';
        _currentChatSessionId = newId;
        _chatHistory.insert(
          0,
          ChatSession(
            id: newId,
            title: title,
            messages: List<ChatMessage>.from(_messages),
            lastActive: DateTime.now(),
          ),
        );
      }
      _currentChatTitle = title;
      // Sort history to keep newest on top
      _chatHistory.sort((a, b) => b.lastActive.compareTo(a.lastActive));
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
      final cartSlugs = CartService().items.map((item) {
        return item.name.toLowerCase().replaceAll(' ', '-');
      }).toList();

      final data = await RecipeAgentService().analyzeAndGetMissing(
        cartSlugs,
        prompt,
        2, // servings
      );

      // Translate backend payload to keys expected by RecipeCard
      final recipeData = {
        'dish': data['dish'] ?? prompt,
        'servings': data['servings'] ?? 2,
        'ready_time': '20 min',
        'summary': data['recipe_instructions'] != null && (data['recipe_instructions'] as List).isNotEmpty
            ? 'A delicious ${data['dish'] ?? prompt} crafted by your AI Chef.'
            : 'A custom recipe for ${data['dish'] ?? prompt}.',
        'ingredients': (data['parsed_ingredients'] as List<dynamic>?)?.map((item) {
          return {
            'name': item['name'] ?? '',
            'quantity': item['quantity'] ?? '1',
          };
        }).toList() ?? [],
        'instructions': List<String>.from(data['recipe_instructions'] ?? []),
        'missing_ingredients': data['missing_ingredients'],
      };

      setState(() {
        _messages.add(ChatMessage(isUser: false, recipe: recipeData));
      });

      _saveCurrentChat();
    } catch (e) {
      debugPrint('[ChatbotScreen] Send message error: $e');
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
    _routeAnimation?.removeStatusListener(_handleRouteStatus);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: HistoryDrawer(
        chatHistory: _chatHistory,
        activeSessionId: _currentChatSessionId,
        onStartNewChat: _startNewChat,
        onOpenChatSession: _openChatSession,
        onDeleteChatSession: _deleteChatSession,
        onRenameChatSession: _renameChatSession,
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
                    theme.colorScheme.primary.withValues(alpha: 0.08),
                    theme.colorScheme.primary.withValues(alpha: 0.0),
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
                    theme.colorScheme.secondary.withValues(alpha: 0.15),
                    theme.colorScheme.secondary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          if (!_isTransitioning)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.transparent),
              ),
            ),
          // Main content
          SafeArea(
            bottom: false,
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
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: FadeContent(
                          key: ValueKey(_currentChatSessionId ?? (_messages.isEmpty ? 'welcome' : 'new_chat')),
                          blur: !_isTransitioning,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: _messages.isEmpty
                              ? SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.only(top: 12, bottom: 48),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const WelcomeCard(),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                                        child: Text(
                                          'Try asking me',
                                          style: TextStyle(
                                            fontFamily: 'ClashDisplay',
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
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
                                  padding: const EdgeInsets.only(top: 12, bottom: 48),
                                  itemCount: _messages.length,
                                  itemBuilder: (_, index) =>
                                      MessageBubble(message: _messages[index]),
                                ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: GradualBlur(
                          height: 32.0,
                          strength: 8,
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: GradualBlur(
                          height: 48.0,
                          strength: 12,
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_loading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
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
    final theme = Theme.of(context);
    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFD2E4E6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.04),
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
                child: Center(
                  child: Icon(
                    Icons.history_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          // Center Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: Text(
              'Qless Assistant',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'ClashDisplay',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
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
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.add_comment_outlined,
                      color: theme.colorScheme.primary,
                      size: 17,
                    ),
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

class WelcomeCard extends StatefulWidget {
  const WelcomeCard({super.key});

  @override
  State<WelcomeCard> createState() => _WelcomeCardState();
}

class _WelcomeCardState extends State<WelcomeCard> {
  bool _startSecondSentence = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: LinearGradient(
          colors: [
            Colors.white,
            theme.colorScheme.secondary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0xFFD2E4E6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 56,
                height: 56,
                child: ClipOval(child: AnimatedOrb(size: 64)),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TypewriterText(
                      text: 'Hi there!',
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                      onComplete: () {
                        setState(() {
                          _startSecondSentence = true;
                        });
                      },
                    ),
                    TypewriterText(
                      text: "I'm your Qless Assistant.",
                      startTyping: _startSecondSentence,
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
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
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration typingSpeed;
  final Duration initialDelay;
  final bool showCursor;
  final String cursorCharacter;
  final VoidCallback? onComplete;
  final bool startTyping;

  const TypewriterText({
    super.key,
    required this.text,
    required this.style,
    this.typingSpeed = const Duration(milliseconds: 60),
    this.initialDelay = Duration.zero,
    this.showCursor = true,
    this.cursorCharacter = '|',
    this.onComplete,
    this.startTyping = true,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayedText = '';
  int _currentCharIndex = 0;
  Timer? _typingTimer;
  Timer? _cursorTimer;
  bool _cursorVisible = true;
  bool _isDone = false;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    if (widget.showCursor) {
      _cursorTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
        if (mounted) {
          setState(() {
            _cursorVisible = !_cursorVisible;
          });
        }
      });
    }
    
    if (widget.startTyping) {
      _triggerStart();
    }
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startTyping && !oldWidget.startTyping && !_hasStarted) {
      _triggerStart();
    }
  }

  void _triggerStart() {
    _hasStarted = true;
    if (widget.initialDelay > Duration.zero) {
      Timer(widget.initialDelay, _startTyping);
    } else {
      _startTyping();
    }
  }

  void _startTyping() {
    if (!mounted) return;
    _typingTimer = Timer.periodic(widget.typingSpeed, (timer) {
      if (!mounted) return;
      if (_currentCharIndex < widget.text.length) {
        setState(() {
          _displayedText += widget.text[_currentCharIndex];
          _currentCharIndex++;
        });
      } else {
        _typingTimer?.cancel();
        setState(() {
          _isDone = true;
        });
        _cursorTimer?.cancel();
        if (widget.onComplete != null) {
          widget.onComplete!();
        }
      }
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasStarted && _displayedText.isEmpty) {
      return RichText(
        text: TextSpan(
          text: widget.text,
          style: widget.style.copyWith(color: Colors.transparent),
        ),
      );
    }

    final typedPart = widget.text.substring(0, _currentCharIndex);
    final remainingPart = widget.text.substring(_currentCharIndex);

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: typedPart,
            style: widget.style,
          ),
          if (widget.showCursor && !_isDone && _cursorVisible)
            TextSpan(
              text: widget.cursorCharacter,
              style: widget.style.copyWith(
                color: widget.style.color?.withOpacity(0.8) ?? Colors.black54,
              ),
            ),
          TextSpan(
            text: remainingPart,
            style: widget.style.copyWith(color: Colors.transparent),
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
    final theme = Theme.of(context);
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
                color: theme.colorScheme.primary.withValues(
                  alpha: _isPressed ? 0.03 : 0.05,
                ),
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
                  color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                ),
                child: Icon(
                  widget.icon,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.text,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FadeContent extends StatefulWidget {
  final Widget child;
  final bool blur;
  final Duration duration;
  final Duration delay;
  final Curve curve;

  const FadeContent({
    super.key,
    required this.child,
    this.blur = true,
    this.duration = const Duration(milliseconds: 1000),
    this.delay = Duration.zero,
    this.curve = Curves.easeOut,
  });

  @override
  State<FadeContent> createState() => _FadeContentState();
}

class _FadeContentState extends State<FadeContent> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  // didUpdateWidget is removed to ensure the fade/blur animation only plays once on mounting (switching chats or creating a new chat) and not when sending messages.

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, childWidget) {
        final double opacity = _animation.value;
        final double sigma = widget.blur ? (1.0 - _animation.value) * 10.0 : 0.0;

        Widget current = Opacity(
          opacity: opacity,
          child: childWidget,
        );

        if (sigma > 0.1) {
          current = ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
            child: current,
          );
        }

        return current;
      },
      child: widget.child,
    );
  }
}

class GradualBlur extends StatelessWidget {
  final double strength;
  final int divCount;
  final double height;
  final Alignment begin;
  final Alignment end;

  const GradualBlur({
    super.key,
    this.strength = 15.0,
    this.divCount = 5,
    this.height = 40.0,
    this.begin = Alignment.topCenter,
    this.end = Alignment.bottomCenter,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: Stack(
          children: List.generate(divCount, (index) {
            final double progress = (index + 1) / divCount;
            final double blurValue = progress * strength;
            
            final double start = index / divCount;
            final double endVal = progress;

            return Positioned.fill(
              child: ShaderMask(
                shaderCallback: (rect) {
                  return LinearGradient(
                    begin: begin,
                    end: end,
                    colors: const [
                      Colors.transparent,
                      Colors.black,
                    ],
                    stops: [
                      start,
                      endVal,
                    ],
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstIn,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

