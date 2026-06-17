import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:ui';

import '../../models/chatbot_models.dart';
import 'widgets/message_bubble.dart';
import 'widgets/chat_input_field.dart';
import 'widgets/history_drawer.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  String? _selectedFileName;
  PlatformFile? _selectedFile;
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
          );
        }).toList();

        return ChatSession(
          title: data['title'] as String,
          messages: messages,
        );
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
      final raw = jsonEncode(_chatHistory.map((session) {
        return {
          'title': session.title,
          'messages': session.messages.map((message) {
            return {
              'isUser': message.isUser,
              'text': message.text,
              'recipe': message.recipe,
            };
          }).toList(),
        };
      }).toList());
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
    Navigator.pop(context);
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
        ChatSession(
          title: title,
          messages: List<ChatMessage>.from(_messages),
        ),
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
            body: jsonEncode({
              'dish': prompt,
              'servings': 2,
            }),
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
            _messages.add(
              ChatMessage(isUser: false, recipe: data),
            );
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
          const ChatMessage(
            isUser: false,
            text: 'Request timed out. Please try again.',
          ),
        );
      });

      _saveCurrentChat();
    } catch (e) {
      setState(() {
        _messages.add(
          const ChatMessage(
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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: HistoryDrawer(
        chatHistory: _chatHistory,
        onStartNewChat: _startNewChat,
        onOpenChatSession: _openChatSession,
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Recipe Assistant',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: const Color(0xFFD2E4E6)),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Builder(
                builder: (context) => IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.history, color: theme.colorScheme.primary, size: 20),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFD2E4E6)),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.home_outlined, color: theme.colorScheme.primary, size: 20),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background soft gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.scaffoldBackgroundColor,
                    Color.lerp(theme.scaffoldBackgroundColor, Colors.white, 0.5) ?? Colors.white,
                    theme.scaffoldBackgroundColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          // Colorful glowing gradient bubbles (Orbs)
          Positioned(
            top: 20,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.12),
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
              width: 250,
              height: 250,
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
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (_, index) => MessageBubble(message: _messages[index]),
                  ),
                ),
                if (_loading)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Generating recipe...',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
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
                  selectedFileName: _selectedFileName,
                  onImageSelected: (image) {
                    setState(() {
                      _selectedImage = image;
                    });
                  },
                  onFileSelected: (file, fileName) {
                    setState(() {
                      _selectedFile = file;
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
                      _selectedFile = null;
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
