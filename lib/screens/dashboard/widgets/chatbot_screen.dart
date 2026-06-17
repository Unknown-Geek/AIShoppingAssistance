import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class ChatSession {
  final String title;
  final List<_ChatMessage> messages;

  ChatSession({required this.title, required this.messages});
}

class _ChatMessage {
  final bool isUser;
  final String? text;
  final Map<String, dynamic>? recipe;

  const _ChatMessage({required this.isUser, this.text, this.recipe});
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _loading = false;
  final List<_ChatMessage> _messages = [];
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
          return _ChatMessage(
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
    final title = _currentChatTitle != 'New Chat' ? _currentChatTitle : 'Chat ${_chatHistory.length + 1}';
    _chatHistory.removeWhere((c) => c.title == title);
    _chatHistory.insert(
      0,
      ChatSession(title: title, messages: List.from(_messages)),
    );
    _saveChatHistory();
  }

  Future<void> _sendMessage() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty || _loading) return;

    setState(() {
      _messages.add(_ChatMessage(isUser: true, text: prompt));
      if (_messages.length == 1) {
        _currentChatTitle = prompt;
      }
      _loading = true;
    });

    _controller.clear();
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/recipe-agent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'dish': prompt, 'servings': 2}),
      );

      dynamic data;
      try {
        data = jsonDecode(response.body);
      } on FormatException {
        data = null;
      }

      if (response.statusCode == 200 && data is Map<String, dynamic>) {
        if (data['status'] == 'success') {
          setState(() {
            _messages.add(_ChatMessage(isUser: false, recipe: data));
          });
        } else {
          final message = data['message'] as String? ?? 'Recipe not found';
          setState(() {
            _messages.add(_ChatMessage(isUser: false, text: message));
          });
        }
        _saveCurrentChat();
      } else {
        final errorMessage = data is Map<String, dynamic>
            ? data['message'] as String? ?? 'Recipe service returned ${response.statusCode}.'
            : 'Recipe service returned ${response.statusCode}.';
        setState(() {
          _messages.add(_ChatMessage(isUser: false, text: errorMessage));
        });
        _saveCurrentChat();
      }
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          isUser: false,
          text: 'Unable to connect to recipe service.',
        ));
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

  Widget _recipeCard(Map<String, dynamic> recipe) {
    final ingredients = List<Map<String, dynamic>>.from(recipe['ingredients'] ?? []);
    final instructions = List<String>.from(recipe['instructions'] ?? []);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recipe['dish'] ?? 'Recipe',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Servings: ${recipe['servings'] ?? ''}',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 18),
          const Text(
            'Ingredients',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 10),
          ...ingredients.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 6),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${item['quantity'] ?? ''} ${item['name'] ?? ''}'),
                  ),
                ],
              ),
            ),
          ),
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Instructions',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 10),
            ...instructions.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text('${entry.key + 1}. ${entry.value}'),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessage(_ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: message.isUser
            ? Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  message.text ?? '',
                  style: const TextStyle(color: Colors.white),
                ),
              )
            : message.recipe != null
                ? _recipeCard(message.recipe!)
                : Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(message.text ?? 'Unknown error'),
                  ),
      ),
    );
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
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Color(0xFFF7F8FA)),
                child: Text(
                  'History',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('New Chat'),
                onTap: _startNewChat,
              ),
              const Divider(),
              Expanded(
                child: _chatHistory.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No saved chats yet.'),
                      )
                    : ListView.builder(
                        itemCount: _chatHistory.length,
                        itemBuilder: (context, index) {
                          final session = _chatHistory[index];
                          return ListTile(
                            leading: const Icon(Icons.chat_bubble_outline),
                            title: Text(
                              session.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _openChatSession(session),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Recipe Assistant'),
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (_, index) => _buildMessage(_messages[index]),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('Generating recipe...'),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Colors.white),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: _loading ? null : (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Ask for a recipe...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _loading ? null : _sendMessage,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
