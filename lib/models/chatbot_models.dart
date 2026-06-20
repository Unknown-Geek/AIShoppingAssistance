class ChatSession {
  final String id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime lastActive;

  ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.lastActive,
  });
}

class ChatMessage {
  final bool isUser;
  final String? text;
  final Map<String, dynamic>? recipe;
  final DateTime timestamp;

  ChatMessage({
    required this.isUser,
    this.text,
    this.recipe,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
