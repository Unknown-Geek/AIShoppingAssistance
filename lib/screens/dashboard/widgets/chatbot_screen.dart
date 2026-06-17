import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recipe_response.dart';
import '../models/ingredient_model.dart';
import '../models/cart_item_model.dart';
import '../services/recipe_agent_service.dart';
import '../services/cart_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

// ── Data ───────────────────────────────────────────────────────────────────

class _Message {
  final String text;
  final bool isUser;
  final RecipeResponse? response;
  _Message({required this.text, required this.isUser, this.response});
}

class _Conversation {
  final String id;
  String title;
  final List<_Message> messages;
  final DateTime createdAt;
  _Conversation({required this.id, required this.title, DateTime? createdAt})
      : messages = [],
        createdAt = createdAt ?? DateTime.now();
}

// ── State ──────────────────────────────────────────────────────────────────

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _agent       = RecipeAgentService();
  final _cartService = CartService();
  final _supabase    = Supabase.instance.client;
  final _stt         = SpeechToText();
  final _controller  = TextEditingController();
  final _scrollCtrl  = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _sttReady    = false;
  bool _isListening = false;
  bool _isLoading   = false;
  String _liveText  = '';

  final List<_Conversation> _conversations = [];
  _Conversation? _active;

  @override
  void initState() {
    super.initState();
    _initStt();
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Supabase history ──────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    final user = _supabase.auth.currentUser;
    if (user == null) { _newChat(); return; }

    try {
      final data = await _supabase
          .from('chat_history')
          .select()
          .eq('user_id', user.id)
          .order('updated_at', ascending: false);

      final loaded = (data as List).map((row) {
        final conv = _Conversation(
          id: row['conversation_id'],
          title: row['title'],
          createdAt: DateTime.parse(row['created_at']),
        );
        for (final m in row['messages'] as List) {
          conv.messages.add(_Message(
            text: m['text'],
            isUser: m['isUser'],
          ));
        }
        return conv;
      }).toList();

      setState(() {
        _conversations..clear()..addAll(loaded);
        _active = _conversations.isNotEmpty ? _conversations.first : null;
      });
    } catch (e) {
      debugPrint('[ChatbotScreen] load error: $e');
    }

    if (_conversations.isEmpty) _newChat();
  }

  Future<void> _saveConversation(_Conversation c) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      await _supabase.from('chat_history').upsert({
        'user_id': user.id,
        'conversation_id': c.id,
        'title': c.title,
        'messages': c.messages.map((m) => {
          'text': m.text,
          'isUser': m.isUser,
        }).toList(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[ChatbotScreen] save error: $e');
    }
  }

  // ── STT ───────────────────────────────────────────────────────────────────

  Future<void> _initStt() async {
    final ok = await _stt.initialize(
      onError: (_) => setState(() => _isListening = false),
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          setState(() => _isListening = false);
          if (_liveText.trim().isNotEmpty) {
            _controller.text = _liveText.trim();
            _liveText = '';
            _send();
          }
        }
      },
    );
    setState(() => _sttReady = ok);
  }

  void _startListening() async {
    if (!_sttReady || _isListening) return;
    setState(() { _isListening = true; _liveText = ''; });
    await _stt.listen(
      onResult: (r) => setState(() => _liveText = r.recognizedWords),
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenMode: ListenMode.confirmation,
    );
  }

  void _stopListening() async {
    if (!_isListening) return;
    await _stt.stop();
  }

  // ── Cart ──────────────────────────────────────────────────────────────────

  void _addOne(IngredientModel ing) {
    _cartService.addItem(CartItemModel(
      id: ing.name.toLowerCase().replaceAll(' ', '_'),
      name: ing.name,
      details: '${ing.quantity} ${ing.unit}',
      imageUrl: '',
      price: 0.0,
    ));
    _snack('${ing.name} added to cart');
  }

  void _addAll(RecipeResponse r, int servings) {
    final factor = servings / r.servings;
    for (final ing in r.ingredients) {
      _cartService.addItem(CartItemModel(
        id: ing.name.toLowerCase().replaceAll(' ', '_'),
        name: ing.name,
        details: '${(ing.quantity * factor).toStringAsFixed(2)} ${ing.unit}',
        imageUrl: '',
        price: 0.0,
      ));
    }
    Navigator.pop(context);
    _snack('All ingredients added to cart');
  }

  void _showServingsDialog(RecipeResponse response) {
    int servings = response.servings;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('How many servings?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () { if (servings > 1) set(() => servings--); },
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              Text('$servings',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              IconButton(
                onPressed: () => set(() => servings++),
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF001A23),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _addAll(response, servings),
              child: const Text('Add to Cart', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Chat ──────────────────────────────────────────────────────────────────

  void _newChat() {
    final c = _Conversation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'New Chat',
    );
    setState(() { _conversations.insert(0, c); _active = c; });
    _saveConversation(c);
  }

  void _switchChat(_Conversation c) {
    setState(() => _active = c);
    Navigator.pop(context);
    _scrollToBottom();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;
    _controller.clear();

    _addMsg(_Message(text: text, isUser: true));
    if (_active!.messages.length == 1) {
      setState(() => _active!.title =
          text.length > 30 ? '${text.substring(0, 30)}…' : text);
    }

    setState(() => _isLoading = true);
    try {
      final res = await _agent.processPrompt(text);
      _addMsg(_Message(text: res.dishName, isUser: false, response: res));
    } catch (_) {
      _addMsg(_Message(text: 'Something went wrong. Try again.', isUser: false));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addMsg(_Message m) {
    setState(() => _active!.messages.add(m));
    _scrollToBottom();
    if (_active != null) _saveConversation(_active!);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF001A23),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFB),
      drawer: _drawer(),
      appBar: _appBar(),
      body: Column(
        children: [
          Expanded(child: _messageList()),
          if (_isLoading) _typingIndicator(),
          if (_isListening) _voiceBar(),
          _inputBar(),
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _appBar() => AppBar(
    elevation: 0,
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    leading: IconButton(
      icon: const Icon(Icons.history_rounded, color: Color(0xFF001A23)),
      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
    ),
    centerTitle: true,
    title: const Text(
      'Shopping Assistant',
      style: TextStyle(
        fontFamily: 'ClashDisplay',
        fontWeight: FontWeight.w600,
        fontSize: 20,
        color: Color(0xFF1A202C),
      ),
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.add_rounded, color: Color(0xFF001A23)),
        onPressed: _newChat,
      ),
      IconButton(
        icon: const Icon(Icons.home_outlined, color: Color(0xFF001A23)),
        onPressed: () => Navigator.pop(context),
      ),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(color: const Color(0xFFD2E4E6), height: 1),
    ),
  );

  // ── Drawer ────────────────────────────────────────────────────────────────

  Widget _drawer() => Drawer(
    backgroundColor: Colors.white,
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('History',
                    style: TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF001A23),
                    )),
                IconButton(
                  icon: const Icon(Icons.add_rounded, color: Color(0xFF4A5568)),
                  onPressed: () { Navigator.pop(context); _newChat(); },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFD2E4E6)),
          Expanded(
            child: _conversations.isEmpty
                ? const Center(
                    child: Text('No conversations yet',
                        style: TextStyle(
                          fontFamily: 'ClashGrotesk',
                          color: Color(0xFF4A5568),
                        )))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _conversations.length,
                    itemBuilder: (_, i) => _chatTile(_conversations[i]),
                  ),
          ),
        ],
      ),
    ),
  );

  Widget _chatTile(_Conversation c) {
    final active = c.id == _active?.id;
    return ListTile(
      selected: active,
      selectedTileColor: const Color(0xFFE8F1F2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(Icons.chat_bubble_outline_rounded,
          size: 18,
          color: active ? const Color(0xFF001A23) : const Color(0xFF4A5568)),
      title: Text(c.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'ClashGrotesk',
            fontSize: 14,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: const Color(0xFF001A23),
          )),
      subtitle: Text(_timeAgo(c.createdAt),
          style: const TextStyle(fontSize: 11, color: Color(0xFF4A5568))),
      onTap: () => _switchChat(c),
    );
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  Widget _messageList() {
    final msgs = _active?.messages ?? [];
    if (msgs.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.restaurant_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('What would you like to cook?',
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                color: Color(0xFF4A5568),
                fontSize: 16,
              )),
        ]),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(16),
      itemCount: msgs.length,
      itemBuilder: (_, i) => _bubble(msgs[i]),
    );
  }

  Widget _bubble(_Message msg) {
    final theme = Theme.of(context);
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: msg.isUser ? theme.colorScheme.secondary : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFD2E4E6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: msg.isUser
            ? Text(msg.text,
                style: TextStyle(
                  fontFamily: 'ClashGrotesk',
                  color: theme.colorScheme.primary,
                  fontSize: 15,
                  height: 1.5,
                ))
            : msg.response == null
                ? Text(msg.text,
                    style: const TextStyle(
                      fontFamily: 'ClashGrotesk',
                      color: Color(0xFF2D3748),
                      fontSize: 15,
                      height: 1.5,
                    ))
                : _recipeCard(msg.response!),
      ),
    );
  }

  Widget _recipeCard(RecipeResponse r) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.dishName,
                  style: const TextStyle(
                    fontFamily: 'ClashDisplay',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF001A23),
                  )),
              Text('${r.servings} servings',
                  style: const TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 12,
                    color: Color(0xFF4A5568),
                  )),
            ]),
          ),
          GestureDetector(
            onTap: () => _showServingsDialog(r),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF001A23),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(children: [
                Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text('Add all',
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      color: Colors.white,
                      fontSize: 12,
                    )),
              ]),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      const Text('Ingredients',
          style: TextStyle(
            fontFamily: 'ClashGrotesk',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4A5568),
          )),
      const SizedBox(height: 6),
      ...r.ingredients.map((i) => GestureDetector(
        onTap: () => _addOne(i),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Container(
              width: 4, height: 4,
              margin: const EdgeInsets.only(right: 8, top: 2),
              decoration: const BoxDecoration(
                  color: Color(0xFF4A5568), shape: BoxShape.circle),
            ),
            Expanded(
              child: Text('${i.name}  ·  ${i.quantity} ${i.unit}',
                  style: const TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 13,
                    color: Color(0xFF2D3748),
                  )),
            ),
            const Icon(Icons.add_rounded, size: 14, color: Color(0xFF4A5568)),
          ]),
        ),
      )),
      if (r.recommendations.isNotEmpty) ...[
        const SizedBox(height: 12),
        const Text('Goes well with',
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A5568),
            )),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: r.recommendations.map((rec) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD2E4E6)),
            ),
            child: Text(rec,
                style: const TextStyle(
                  fontFamily: 'ClashGrotesk',
                  fontSize: 12,
                  color: Color(0xFF2D3748),
                )),
          )).toList(),
        ),
      ],
    ],
  );

  // ── Voice bar ─────────────────────────────────────────────────────────────

  Widget _voiceBar() => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFD2E4E6)),
    ),
    child: Row(children: [
      const Icon(Icons.mic_rounded, size: 16, color: Colors.redAccent),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          _liveText.isEmpty ? 'Listening…' : _liveText,
          style: TextStyle(
            fontFamily: 'ClashGrotesk',
            fontSize: 13,
            color: _liveText.isEmpty
                ? const Color(0xFF4A5568)
                : const Color(0xFF001A23),
          ),
        ),
      ),
    ]),
  );

  // ── Typing indicator ──────────────────────────────────────────────────────

  Widget _typingIndicator() => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD2E4E6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) => _Dot(delay: i * 200)),
      ),
    ),
  );

  // ── Input bar ─────────────────────────────────────────────────────────────

  Widget _inputBar() {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFD2E4E6))),
        ),
        child: Row(children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7F8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(fontFamily: 'ClashGrotesk'),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: 'Ask anything...',
                  hintStyle: TextStyle(fontFamily: 'ClashGrotesk'),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Mic — hold to speak
          GestureDetector(
            onLongPressStart: (_) => _startListening(),
            onLongPressEnd: (_) => _stopListening(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: _isListening
                    ? Colors.redAccent
                    : const Color(0xFFD2E4E6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: _isListening ? Colors.white : const Color(0xFF4A5568),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary,
              ),
              child: Icon(
                Icons.arrow_upward,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

// ── Dot ───────────────────────────────────────────────────────────────────

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay),
        () { if (mounted) _ctrl.repeat(reverse: true); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(
      width: 6, height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: const BoxDecoration(
          color: Color(0xFF4A5568), shape: BoxShape.circle),
    ),
  );
}