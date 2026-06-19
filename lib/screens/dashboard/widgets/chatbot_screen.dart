import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatSession {
  final String title;
  final List<ChatMessage> messages;

  _ChatSession({required this.title, required this.messages});
}

class ChatMessage {
  final bool isUser;
  final String? text;
  final Map<String, dynamic>? recipe;

  const ChatMessage({required this.isUser, this.text, this.recipe});
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  String? _selectedFileName;
  PlatformFile? _selectedFile;
  XFile? _selectedImage;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _loading = false;
  final List<ChatMessage> _messages = [];
  final List<_ChatSession> _chatHistory = [];
  String _currentChatTitle = 'New Chat';

  static const String _storageKey = 'chat_history_v1';

  static final String baseUrl = (() {
    final raw = dotenv.env['HF_SPACE_URL']?.trim() ?? '';
    if (raw.isEmpty) return 'http://127.0.0.1:8000';
    var clean = raw.replaceAll(RegExp(r'/health$'), '');
    clean = clean.replaceAll(RegExp(r'/detect$'), '');
    clean = clean.replaceAll(RegExp(r'/embed$'), '');
    clean = clean.replaceAll(RegExp(r'/recipe/analyze-ingredients/$'), '');
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

        return _ChatSession(
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

  void _openChatSession(_ChatSession session) {
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
      _ChatSession(
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

  if (_selectedFileName != null || _selectedImage != null || _selectedFile != null) {
    debugPrint('[ChatbotScreen] Attachment selected: ${_selectedFileName ?? _selectedFile?.name ?? _selectedImage?.path}');
  }

  setState(() {
    _messages.add(ChatMessage(isUser: true, text: prompt));

    if (_messages.length == 1) {
      _currentChatTitle = prompt;
    }

    _loading = true;
    _selectedFileName = null;
    _selectedFile = null;
    _selectedImage = null;
  });

  _saveCurrentChat();
  _controller.clear();
  _scrollToBottom();

  try {
    final response = await http
        .post(
          Uri.parse('$baseUrl/recipe/analyze-ingredients/'),
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
      if (data['is_conversational'] == true) {
        setState(() {
          _messages.add(
            ChatMessage(
              isUser: false,
              text: data['response_text'] ?? 'How can I assist you today?',
            ),
          );
        });
      } else if (data['status'] == 'success' || data.containsKey('dish')) {
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

  Widget _buildMessage(ChatMessage message) {
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
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedImage != null || _selectedFileName != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (_selectedImage != null)
                          InputChip(
                            avatar: const Icon(Icons.image, size: 16),
                            label: Text(_selectedImage!.name.split('/').last),
                            onDeleted: () {
                              setState(() {
                                _selectedImage = null;
                              });
                            },
                          ),
                        if (_selectedFileName != null)
                          InputChip(
                            avatar: const Icon(Icons.attach_file, size: 16),
                            label: Text(_selectedFileName!),
                            onDeleted: () {
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onSubmitted: _loading ? null : (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: 'Ask for a recipe...',
                          filled: true,
                          fillColor: const Color(0xFFF3F4F6),

                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),

                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),

                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),

                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Center(
                              widthFactor: 1,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.add,
                                    size: 18,
                                  ),
                                  onPressed: () async {
                                    showModalBottomSheet(
                                      context: context,
                                      builder: (context) => SafeArea(
                                        child: Wrap(
                                          children: [
                                            ListTile(
                                              leading: const Icon(Icons.image),
                                              title: const Text('Choose Image'),
                                              onTap: () async {
                                                Navigator.pop(context);

                                                final image =
                                                    await _imagePicker.pickImage(
                                                  source: ImageSource.gallery,
                                                );

                                                if (image != null) {
                                                  setState(() {
                                                    _selectedImage = image;
                                                  });
                                                }
                                              },
                                            ),
                                            ListTile(
                                              leading: const Icon(Icons.attach_file),
                                              title: const Text('Choose File'),
                                              onTap: () async {
                                                Navigator.pop(context);

                                                final result =
                                                    await FilePicker.platform.pickFiles();

                                                if (result != null &&
                                                    result.files.isNotEmpty) {
                                                  setState(() {
                                                    _selectedFile =
                                                        result.files.first;
                                                    _selectedFileName =
                                                        result.files.first.name;
                                                  });
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),

                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.mic_none_rounded,
                              size: 22,
                            ),
                            onPressed: () {
                              // Speech-to-text later
                            },
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.black,
                      child: IconButton(
                        onPressed: _loading ? null : _sendMessage,
                        icon: const Icon(
                          Icons.arrow_upward,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
