import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _loading = false;

  // CHANGE THIS
  static const String baseUrl =
      "http://127.0.0.1:8000"; // local backend

  final List<Map<String, dynamic>> _messages = [];

  Future<void> _sendMessage() async {
    final prompt = _controller.text.trim();

    if (prompt.isEmpty) return;

    setState(() {
      _messages.add({
        "isUser": true,
        "text": prompt,
      });
      _loading = true;
    });

    _controller.clear();

    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/recipe-agent"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "dish": prompt,
          "servings": 2,
        }),
      );

      final data = jsonDecode(response.body);

      if (data["status"] == "success") {
        setState(() {
          _messages.add({
            "isUser": false,
            "recipe": data,
          });
        });
      } else {
        setState(() {
          _messages.add({
            "isUser": false,
            "text": data["message"] ?? "Recipe not found",
          });
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({
          "isUser": false,
          "text": "Unable to connect to recipe service.",
        });
      });
    }

    setState(() {
      _loading = false;
    });

    _scrollToBottom();
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
    final ingredients =
        List<Map<String, dynamic>>.from(recipe["ingredients"] ?? []);

    final instructions =
        List<String>.from(recipe["instructions"] ?? []);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recipe["dish"] ?? "Recipe",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Servings: ${recipe["servings"]}",
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            "Ingredients",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          ...ingredients.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(
                    Icons.circle,
                    size: 6,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${item["quantity"] ?? ""} ${item["name"] ?? ""}",
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              "Instructions",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            ...instructions.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      "${entry.key + 1}. ${entry.value}",
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    final isUser = message["isUser"] ?? false;

    return Align(
      alignment:
          isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 600,
        ),
        margin: const EdgeInsets.symmetric(
          vertical: 6,
          horizontal: 12,
        ),
        child: isUser
            ? Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  message["text"],
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                ),
              )
            : message.containsKey("recipe")
                ? _recipeCard(message["recipe"])
                : Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      message["text"],
                    ),
                  ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text("Recipe Assistant"),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (_, index) =>
                  _buildMessage(_messages[index]),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: "Ask for a recipe...",
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(16),
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