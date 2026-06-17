import 'package:flutter/material.dart';
import '../../../models/chatbot_models.dart';

class HistoryDrawer extends StatelessWidget {
  final List<ChatSession> chatHistory;
  final VoidCallback onStartNewChat;
  final ValueChanged<ChatSession> onOpenChatSession;

  const HistoryDrawer({
    super.key,
    required this.chatHistory,
    required this.onStartNewChat,
    required this.onOpenChatSession,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
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
              onTap: onStartNewChat,
            ),
            const Divider(),
            Expanded(
              child: chatHistory.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No saved chats yet.'),
                    )
                  : ListView.builder(
                      itemCount: chatHistory.length,
                      itemBuilder: (context, index) {
                        final session = chatHistory[index];
                        return ListTile(
                          leading: const Icon(Icons.chat_bubble_outline),
                          title: Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => onOpenChatSession(session),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
