import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/chat/data/mock_chats.dart';
import 'package:syntrace/features/chat/data/models/chat_message.dart';
import 'package:syntrace/features/chat/data/models/chat_session.dart';
import 'package:syntrace/features/chat/presentation/widgets/chat_history_drawer.dart';
import 'package:syntrace/features/chat/presentation/widgets/chat_input.dart';
import 'package:syntrace/features/chat/presentation/widgets/message_bubble.dart';
import 'package:syntrace/features/chat/presentation/widgets/typing_indicator.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<ChatMessage> _messages = [];
  List<ChatSession> _sessions = [];
  String? _selectedSessionId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _sessions = MockChats.sessions;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════
  // New Chat
  // ═══════════════════════════════════════════════════════
  void _handleNewChat() {
    setState(() {
      _messages.clear();
      _selectedSessionId = null;
    });
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  // ═══════════════════════════════════════════════════════
  // Session Tap
  // ═══════════════════════════════════════════════════════
  void _handleSessionTap(ChatSession session) {
    setState(() {
      _selectedSessionId = session.id;
      _messages.clear();
      if (session.id == '1') {
        _messages.addAll(MockChats.messages);
      } else {
        _messages.addAll(MockChats.messages.take(2));
      }
    });
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    _scrollToBottom();
  }

  // ═══════════════════════════════════════════════════════
  // Send Message
  // ═══════════════════════════════════════════════════════
  void _handleSend(String text) {
    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: ChatRole.user,
        content: text,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: ChatRole.ai,
          timestamp: DateTime.now(),
          content:
              'This is a mock response.\n\nYou asked: **"$text"**\n\nThe real AI will be connected soon.',
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    });
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

  // ═══════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        if (isWide) {
          return _buildWebLayout(context);
        }
        return _buildMobileLayout(context);
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // Web Layout: Sidebar + Content
  // ═══════════════════════════════════════════════════════
  Widget _buildWebLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          // ─── Chat History Sidebar ───
          ChatHistoryPanel(
            sessions: _sessions,
            selectedId: _selectedSessionId,
            onNewChat: _handleNewChat,
            onSessionTap: _handleSessionTap,
          ),

          // ─── Chat Area ───
          Expanded(child: _buildChatArea(context, isMobile: false)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Mobile Layout: Full + Drawer
  // ═══════════════════════════════════════════════════════
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: Drawer(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: ChatHistoryPanel(
          sessions: _sessions,
          selectedId: _selectedSessionId,
          onNewChat: _handleNewChat,
          onSessionTap: _handleSessionTap,
        ),
      ),
      body: _buildChatArea(context, isMobile: true),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Chat Area (Header + Messages + Input)
  // ═══════════════════════════════════════════════════════
  Widget _buildChatArea(BuildContext context, {required bool isMobile}) {
    return Column(
      children: [
        // ─── Chat Header (خفيف، بدون تكرار TopBar) ───
        _buildChatHeader(context, isMobile),

        // ─── Messages ───
        Expanded(
          child: _messages.isEmpty && !_isLoading
              ? _buildEmptyState(context)
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    // ─── Typing Indicator في آخر الليست ───
                    if (index == _messages.length) {
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: const TypingIndicator(),
                        ),
                      );
                    }

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: MessageBubble(message: _messages[index]),
                      ),
                    );
                  },
                ),
        ),

        // ─── Input ───
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ChatInput(
              onSend: _handleSend,
              enabled: !_isLoading,
              isLoading: _isLoading,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // Chat Header (خفيف — مفيش TopBar مكرر)
  // ═══════════════════════════════════════════════════════
  Widget _buildChatHeader(BuildContext context, bool isMobile) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          // ─── Menu (Mobile Only) ───
          if (isMobile)
            IconButton(
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: Icon(
                Icons.menu,
                color: theme.colorScheme.onSurface,
                size: 22,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Chat history',
            ),

          if (isMobile) const SizedBox(width: 12),

          // ─── Title ───
          Text(
            'AI Assistant',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),

          const Spacer(),

          // ─── Clear Chat (بس لو فيه رسايل) ───
          if (_messages.isNotEmpty)
            IconButton(
              onPressed: () => setState(() => _messages.clear()),
              icon: Icon(
                Icons.refresh,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Clear chat',
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Empty State
  // ═══════════════════════════════════════════════════════
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.15),
                    AppColors.secondary.withOpacity(0.15),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'How can I help you?',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask me anything about your projects,\ncommits, bugs, or team.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                'Show me the dependency chain for Task #1847',
                'Why is Sprint 14 delayed?',
                'Show recent bugs',
                'Who worked on auth?',
              ].map((s) {
                return _Suggestion(text: s, onTap: () => _handleSend(s));
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Suggestion Chip
// ═══════════════════════════════════════════════════════════
class _Suggestion extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _Suggestion({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.5),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}