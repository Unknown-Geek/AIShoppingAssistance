class ChatSession {
  final String title;
  final List<ChatMessage> messages;

  ChatSession({required this.title, required this.messages});
}

class ChatMessage {
  final bool isUser;
  final String? text;
  final Map<String, dynamic>? recipe;

  const ChatMessage({required this.isUser, this.text, this.recipe});
}
