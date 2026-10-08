import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/chat/data/models/chat_session.dart';
import 'package:syntrace/features/chat/presentation/cubit/chat_cubit.dart';
import 'package:syntrace/features/chat/presentation/cubit/chat_state.dart';
import 'package:syntrace/features/chat/presentation/widgets/chat_error_banner.dart';
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

  @override
  void initState() {
    super.initState();
    context.read<ChatCubit>().loadChat();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
  Widget build(BuildContext context) {
    return BlocConsumer<ChatCubit, ChatState>(
      listener: (context, state) {
        if (state is ChatLoaded) {
          _scrollToBottom();
        }
        if (state is ChatErrorState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;

            if (isWide) {
              return _buildWebLayout(context, state);
            }
            return _buildMobileLayout(context, state);
          },
        );
      },
    );
  }

  Widget _buildWebLayout(BuildContext context, ChatState state) {
    final sessions = state is ChatLoaded ? state.sessions : <ChatSession>[];
    final selectedId = state is ChatLoaded ? state.currentSessionId : null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          ChatHistoryPanel(
            sessions: sessions,
            selectedId: selectedId,
            onNewChat: () => context.read<ChatCubit>().newChat(),
            onSessionTap: (session) =>
                context.read<ChatCubit>().openSession(session),
          ),
          Expanded(child: _buildChatArea(context, state, isMobile: false)),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, ChatState state) {
    final sessions = state is ChatLoaded ? state.sessions : <ChatSession>[];
    final selectedId = state is ChatLoaded ? state.currentSessionId : null;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: Drawer(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: ChatHistoryPanel(
          sessions: sessions,
          selectedId: selectedId,
          onNewChat: () => context.read<ChatCubit>().newChat(),
          onSessionTap: (session) =>
              context.read<ChatCubit>().openSession(session),
        ),
      ),
      body: _buildChatArea(context, state, isMobile: true),
    );
  }

  Widget _buildChatArea(
    BuildContext context,
    ChatState state, {
    required bool isMobile,
  }) {
    if (state is ChatLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state is ChatErrorState) {
      return _buildErrorState(context, state.message);
    }

    if (state is! ChatLoaded) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        _buildChatHeader(context, state, isMobile),

        if (state.hasError)
          ChatErrorBanner(
            error: state.error!,
            onRetry: () => context.read<ChatCubit>().retryLastMessage(),
            onDismiss: () => context.read<ChatCubit>().dismissError(),
          ),

        Expanded(child: _buildMessages(context, state)),

        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ChatInput(
              onSend: (text) => context.read<ChatCubit>().sendMessage(text),
              enabled: !state.isBusy,
              isLoading: state.isSending,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessages(BuildContext context, ChatLoaded state) {
    if (state.isEmpty && !state.isSending) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: state.messages.length + (state.isSending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.messages.length) {
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
            child: MessageBubble(
              message: state.messages[index],
              onRetry: () => context.read<ChatCubit>().retryLastMessage(),
              onDelete: () => context.read<ChatCubit>().deleteFailedMessage(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatHeader(
    BuildContext context,
    ChatLoaded state,
    bool isMobile,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
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

          Text(
            'AI Assistant',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),

          const Spacer(),

          if (state.messages.isNotEmpty)
            IconButton(
              onPressed: () => context.read<ChatCubit>().clearChat(),
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
                return _Suggestion(
                  text: s,
                  onTap: () => context.read<ChatCubit>().sendMessage(s),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<ChatCubit>().loadChat(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

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