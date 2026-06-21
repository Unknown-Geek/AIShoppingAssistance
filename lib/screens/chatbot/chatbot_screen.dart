import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:ui';

import '../../models/chatbot_models.dart';
import '../../models/cart_item_model.dart';
import 'widgets/message_bubble.dart';
import 'widgets/chat_input_field.dart';
import 'widgets/history_drawer.dart';
import 'widgets/chat_cart_sheet.dart';
import 'widgets/chat_header_pill.dart';
import 'widgets/welcome_card.dart';
import 'widgets/suggestion_pill.dart';
import 'widgets/fade_content.dart';
import 'widgets/gradual_blur.dart';
import '../../services/chat_agent_service.dart';
import '../../services/cart_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  XFile? _selectedImage;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static bool _loading = false;
  static final List<ChatMessage> _messages = [];
  static final List<ChatSession> _chatHistory = [];
  static String _currentChatTitle = 'New Chat';
  static String? _currentChatSessionId;
  static bool _isInitialized = false;
  static final ValueNotifier<int> _updateNotifier = ValueNotifier(0);

  bool _showScrollDownButton = false;
  Animation<double>? _routeAnimation;
  bool _isTransitioning = true;

  static const String _storageKey = 'chat_history_v2'; // Changed key to differentiate updated model storage

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final showButton = maxScroll - currentScroll > 200;
    if (showButton != _showScrollDownButton) {
      setState(() {
        _showScrollDownButton = showButton;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _updateNotifier.addListener(_onGlobalUpdate);
    if (!_isInitialized) {
      _currentChatSessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      _loadChatHistory();
      _isInitialized = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
    _scrollController.addListener(_onScroll);
  }

  void _onGlobalUpdate() {
    if (mounted) setState(() {});
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
        if (_chatHistory.isNotEmpty) {
          final mostRecent = _chatHistory.first;
          _messages.clear();
          _messages.addAll(mostRecent.messages);
          _currentChatTitle = mostRecent.title;
          _currentChatSessionId = mostRecent.id;
        }
      });
      if (restored.isNotEmpty) {
        _scrollToBottom();
      }
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

    void updateState() {
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
    }

    updateState();
    _updateNotifier.value++;

    _saveChatHistory();
  }

  Future<void> _sendMessage() async {
    final prompt = _controller.text.trim();
    final imageFile = _selectedImage;
    if ((prompt.isEmpty && imageFile == null) || _loading) return;

    setState(() {
      _messages.add(ChatMessage(
        isUser: true,
        text: prompt.isEmpty ? "Sent a photo" : prompt,
      ));

      if (_messages.length == 1) {
        _currentChatTitle = prompt.isEmpty ? "Image Scan" : prompt;
      }

      _loading = true;
      _selectedImage = null;
    });

    _saveCurrentChat();
    _controller.clear();
    _scrollToBottom();

    try {
      String? base64Image;
      if (imageFile != null) {
        final bytes = await imageFile.readAsBytes();
        base64Image = base64Encode(bytes);
      }

      final cartSlugs = CartService().items.map((item) {
        return item.name.toLowerCase().replaceAll(' ', '-');
      }).toList();

      final currentCart = CartService().items.map((item) {
        return {
          "sku": item.id,
          "name": item.name,
          "quantity": item.quantity,
        };
      }).toList();

      // Sanitize chat history: strip any assistant messages that echo cart state.
      // Those are snapshots of a past moment — if the cart has since been cleared
      // or modified via the dashboard scanner, they become stale and cause the LLM
      // to double-count quantities across turns.
      final rawHistory = _messages.sublist(0, _messages.length - 1);
      final sanitizedHistory = rawHistory.map((msg) {
        if (!msg.isUser &&
            msg.text != null &&
            (msg.text!.contains('Current Cart Items:') ||
             msg.text!.startsWith('- ') && msg.text!.contains(':'))) {
          // Replace stale cart listing with a neutral note so history context is preserved
          // without the outdated quantity data polluting the LLM's reasoning.
          return ChatMessage(
            isUser: false,
            text: '[Previous cart summary — refer to system prompt for current cart state]',
            timestamp: msg.timestamp,
          );
        }
        return msg;
      }).toList();

      final response = await ChatAgentService().sendChatMessage(
        cartSlugs,
        currentCart,
        prompt,
        2, // servings
        sanitizedHistory,
        imageBase64: base64Image,
      );

      final String responseText = response['response_text'] ?? '';
      final List<dynamic>? mutations = response['cart_mutations'] != null ? List<dynamic>.from(response['cart_mutations']) : null;
      final Map<String, dynamic>? recipePayload = response['recipe'] != null ? Map<String, dynamic>.from(response['recipe']) : null;

      // Handle mutations if any
      if (mutations != null) {
        for (final mutation in mutations) {
          try {
            final action = mutation['action'];
            final sku = mutation['sku'];
            final name = mutation['name'] ?? 'Unknown Item';
            final price = (mutation['price'] as num?)?.toDouble() ?? 50.0;
            final quantity = (mutation['quantity'] as num?)?.toInt() ?? 1;

            if (action == 'add') {
              CartService().addItem(
                CartItemModel(
                  id: sku ?? 'unknown_sku_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  price: price,
                  quantity: quantity,
                  details: 'Added by Qless Assistant',
                  imageUrl: mutation['thumbnail_url'] ?? '',
                ),
              );
            } else if (action == 'remove') {
              CartService().removeOrDecrementItemBySkuOrName(sku ?? '', name, quantity);
            } else if (action == 'clear') {
              CartService().clearCart();
            }
          } catch (exMut) {
            debugPrint('[ChatbotScreen] Mutation error: $exMut');
          }
        }
      }

      // Handle recipe or message display
      ChatMessage assistantMessage;
      if (recipePayload != null) {
        final recipeData = {
          'dish': recipePayload['dish'] ?? prompt,
          'servings': recipePayload['servings'] ?? 2,
          'ready_time': '20 min',
          'summary': recipePayload['recipe_instructions'] != null && (recipePayload['recipe_instructions'] as List).isNotEmpty
              ? 'A delicious ${recipePayload['dish'] ?? prompt} crafted by your AI Chef.'
              : 'A custom recipe for ${recipePayload['dish'] ?? prompt}.',
          'ingredients': (recipePayload['ingredients'] as List<dynamic>?)?.map((item) {
            final cleaned = _cleanIngredient(
              item['quantity'] ?? '',
              item['name'] ?? '',
            );
            return {
              'name': cleaned['name'] ?? '',
              'quantity': cleaned['quantity'] ?? '1',
            };
          }).toList() ?? [],
          'instructions': List<String>.from(recipePayload['recipe_instructions'] ?? []),
          'missing_ingredients': recipePayload['missing_ingredients'],
        };
        assistantMessage = ChatMessage(isUser: false, recipe: recipeData);
      } else {
        assistantMessage = ChatMessage(
          isUser: false,
          text: responseText.isNotEmpty ? responseText : 'How can I assist you today?',
        );
      }

      if (mounted) {
        setState(() {
          _messages.add(assistantMessage);
        });
      } else {
        _messages.add(assistantMessage);
      }
      _saveCurrentChat();
    } catch (e) {
      debugPrint('[ChatbotScreen] Send message error: $e');
      final errorMsg = ChatMessage(
        isUser: false,
        text: 'Unable to connect to assistant service.',
      );
      if (mounted) {
        setState(() {
          _messages.add(errorMsg);
        });
      } else {
        _messages.add(errorMsg);
      }
      _saveCurrentChat();
    } finally {
      _loading = false;
      _updateNotifier.value++;
      _scrollToBottom();
    }
  }

  Future<void> _analyzeCart() async {
    if (_loading) return;

    setState(() {
      _messages.add(ChatMessage(
        isUser: true,
        text: "Analyze my cart for missing items",
      ));
      _loading = true;
    });

    _saveCurrentChat();
    _scrollToBottom();

    try {
      final currentCart = CartService().items.map((item) {
        return {
          "sku": item.id,
          "name": item.name,
          "quantity": item.quantity,
        };
      }).toList();

      final result = await ChatAgentService().analyzeCart(currentCart);

      final String responseText = result['response_text'] ?? '';
      final List<dynamic> missingItems = result['missing_regulars'] ?? [];

      String finalMessage = responseText;
      if (missingItems.isNotEmpty) {
        finalMessage += "\n\nBased on your past orders, we found the following missing items:";
        for (var item in missingItems) {
          final name = item['name'] ?? 'Unknown Item';
          final avgGap = item['avg_gap_days'] ?? 0;
          final lastBought = item['last_bought_days_ago'] ?? 0;
          final price = item['price'] ?? 0.0;
          
          finalMessage += "\n• $name (₹${price.toStringAsFixed(2)}) - usually bought every $avgGap days, last bought $lastBought days ago.";
        }
      } else {
        finalMessage += "\n\nNo missing regular items detected in your cart. You are all set!";
      }

      final successMsg = ChatMessage(
        isUser: false,
        text: finalMessage,
      );
      if (mounted) {
        setState(() {
          _messages.add(successMsg);
        });
      } else {
        _messages.add(successMsg);
      }
      _saveCurrentChat();
    } catch (e) {
      debugPrint('[ChatbotScreen] Cart analysis error: $e');
      final errorMsg = ChatMessage(
        isUser: false,
        text: 'Unable to perform cart analysis. Please try again later.',
      );
      if (mounted) {
        setState(() {
          _messages.add(errorMsg);
        });
      } else {
        _messages.add(errorMsg);
      }
      _saveCurrentChat();
    } finally {
      _loading = false;
      _updateNotifier.value++;
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

  Map<String, String> _cleanIngredient(String quantity, String name) {
    var qtyStr = quantity.trim();
    var nameStr = name.trim();
    
    if (qtyStr.isEmpty) return {'quantity': '', 'name': nameStr};
    if (nameStr.isEmpty) return {'quantity': qtyStr, 'name': ''};
    
    // 1. Clean the quantity if unit is duplicated in the quantity string itself (e.g. "2 cups cups" -> "2 cups")
    final qtyWords = qtyStr.split(RegExp(r'\s+'));
    if (qtyWords.length >= 2) {
      final lastWord = qtyWords.last;
      final secondLastWord = qtyWords[qtyWords.length - 2];
      
      String cleanWord(String w) {
        var word = w.toLowerCase().trim();
        if (word.endsWith('es')) {
          word = word.substring(0, word.length - 2);
        } else if (word.endsWith('s')) {
          word = word.substring(0, word.length - 1);
        }
        return word;
      }
      
      if (cleanWord(lastWord) == cleanWord(secondLastWord)) {
        qtyStr = qtyWords.sublist(0, qtyWords.length - 1).join(' ').trim();
      }
    }
    
    // 2. Clean the name if it starts with a unit word already present in the quantity
    final nameWords = nameStr.split(RegExp(r'\s+'));
    if (nameWords.isNotEmpty) {
      final firstWord = nameWords.first.toLowerCase().replaceAll(RegExp(r'[.,()]+'), '');
      final qtyWordsForCheck = qtyStr.toLowerCase().split(RegExp(r'\s+'));
      
      String cleanWord(String w) {
        var word = w.toLowerCase().trim();
        if (word.endsWith('es')) {
          word = word.substring(0, word.length - 2);
        } else if (word.endsWith('s')) {
          word = word.substring(0, word.length - 1);
        }
        return word;
      }
      
      final cleanFirst = cleanWord(firstWord);
      
      bool matched = false;
      for (final qWord in qtyWordsForCheck) {
        if (cleanWord(qWord) == cleanFirst) {
          matched = true;
          break;
        }
      }
      
      if (matched) {
        var cleaned = nameWords.sublist(1).join(' ').trim();
        if (cleaned.toLowerCase().startsWith('of ')) {
          cleaned = cleaned.substring(3).trim();
        }
        nameStr = cleaned;
      }
    }
    
    return {'quantity': qtyStr, 'name': nameStr};
  }

  @override
  void dispose() {
    _updateNotifier.removeListener(_onGlobalUpdate);
    _scrollController.removeListener(_onScroll);
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
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Column(
              children: [
                // Floating Header Pill
                ChatHeaderPill(
                  onBackTap: () {
                    Navigator.of(context).pop();
                  },
                  onHistoryTap: () {
                    _scaffoldKey.currentState?.openDrawer();
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
                                            fontFamily: theme.textTheme.titleLarge?.fontFamily,
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
                                              text: 'Analyze my cart for missing items 🛒',
                                              icon: Icons.analytics_outlined,
                                              onTap: () {
                                                _analyzeCart();
                                              },
                                            ),
                                            SuggestionPill(
                                              text: 'What snacks do you have under ₹50?',
                                              icon: Icons.local_offer_outlined,
                                              onTap: () {
                                                _controller.text = 'What snacks do you have under ₹50?';
                                                _sendMessage();
                                              },
                                            ),
                                            SuggestionPill(
                                              text: 'Add 2 Snickers and a KitKat to my cart',
                                              icon: Icons.add_shopping_cart_rounded,
                                              onTap: () {
                                                _controller.text = 'Add 2 Snickers and a KitKat to my cart';
                                                _sendMessage();
                                              },
                                            ),
                                            SuggestionPill(
                                              text: 'Make me a recipe for Maggi noodles',
                                              icon: Icons.restaurant_menu_rounded,
                                              onTap: () {
                                                _controller.text = 'Make me a recipe for Maggi noodles';
                                                _sendMessage();
                                              },
                                            ),
                                            SuggestionPill(
                                              text: "What's the difference between Horlicks and Bournvita?",
                                              icon: Icons.help_outline_rounded,
                                              onTap: () {
                                                _controller.text = "What's the difference between Horlicks and Bournvita?";
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
                                  itemCount: _messages.length + (_loading ? 1 : 0),
                                  itemBuilder: (_, index) {
                                    if (index == _messages.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: MessageBubble(
                                          message: ChatMessage(
                                            isUser: false,
                                            text: null,
                                          ),
                                        ),
                                      );
                                    }
                                    return MessageBubble(message: _messages[index]);
                                  },
                                ),
                        ),
                      ),
                      const Positioned(
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
                      const Positioned(
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
                      if (_showScrollDownButton)
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: GestureDetector(
                            onTap: _scrollToBottom,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFD2E4E6),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: theme.colorScheme.primary,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 16,
                        bottom: 16,
                        child: ListenableBuilder(
                          listenable: CartService(),
                          builder: (context, child) {
                            final count = CartService().itemCount;
                            return GestureDetector(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (ctx) => const ChatCartSheet(),
                                );
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFD2E4E6),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Badge(
                                    label: Text(
                                      '$count',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    isLabelVisible: count > 0,
                                    backgroundColor: theme.colorScheme.secondary,
                                    textColor: theme.colorScheme.primary,
                                    child: Icon(
                                      Icons.shopping_cart_outlined,
                                      color: theme.colorScheme.primary,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                ChatInputField(
                  controller: _controller,
                  loading: _loading,
                  onSend: _sendMessage,
                  selectedImage: _selectedImage,
                  onImageSelected: (image) {
                    setState(() {
                      _selectedImage = image;
                    });
                  },
                  onClearImage: () {
                    setState(() {
                      _selectedImage = null;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }
}
