import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/chat/data/models/chat_message.dart';
import 'package:syntrace/features/chat/presentation/widgets/ai_progress_steps.dart';
import 'package:syntrace/features/chat/presentation/widgets/jira_card_widget.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    this.onRetry,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // ─── Progress Steps (AI Only) ───
          if (!isUser && message.steps.isNotEmpty) ...[
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              child: AiProgressSteps(steps: message.steps),
            ),
            const SizedBox(height: 10),
          ],

          // ─── Message Row ───
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              // ─── Failed Icon (User Message) ───
              if (isUser && message.hasError && onRetry != null) ...[
                _buildFailedIcon(context),
                const SizedBox(width: 8),
              ],

              // ─── Bubble ───
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.85,
                  ),
                  child: isUser
                      ? _buildUserBubble(context)
                      : _buildAiBubble(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Failed Icon (Retry / Delete Menu)
  // ═══════════════════════════════════════════════════════
  Widget _buildFailedIcon(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Options',
      onSelected: (value) {
        if (value == 'retry') onRetry?.call();
        if (value == 'delete') onDelete?.call();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'retry',
          child: Row(
            children: [
              Icon(Icons.refresh, size: 18),
              SizedBox(width: 8),
              Text('Retry'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: AppColors.error),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
      child: Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.error,
        ),
        child: const Icon(
          Icons.priority_high,
          color: Colors.white,
          size: 14,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // User Bubble
  // ═══════════════════════════════════════════════════════
  Widget _buildUserBubble(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: message.hasError
            ? AppColors.error.withOpacity(0.7)
            : AppColors.primary,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: Text(
        message.content,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // AI Bubble
  // ═══════════════════════════════════════════════════════
  Widget _buildAiBubble(BuildContext context) {
    final theme = Theme.of(context);

    // ─── Error Message ───
    if (message.hasError) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: 18,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                message.content,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ─── Normal Message ───
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Empty + Streaming: Blinking Cursor Only ───
          if (message.content.isEmpty && message.isStreaming)
            Row(
              children: [
                _BlinkingCursor(color: theme.colorScheme.onSurface),
              ],
            )
          // ─── Content ───
          else if (message.content.isNotEmpty)
            MarkdownBody(
              data: message.content,
              styleSheet: _markdownStyle(theme),
              selectable: true,
            ),

          // ─── Blinking Cursor during Streaming ───
          if (message.isStreaming && message.content.isNotEmpty) ...[
            const SizedBox(height: 4),
            _BlinkingCursor(color: theme.colorScheme.onSurface),
          ],

          // ─── Jira Cards ───
          if (message.jiraCards.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...message.jiraCards.map((card) {
              return JiraCardWidget(
                card: card,
                onTap: () {
                  // TODO: open URL in browser
                },
              );
            }),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Markdown Style
  // ═══════════════════════════════════════════════════════
  MarkdownStyleSheet _markdownStyle(ThemeData theme) {
    return MarkdownStyleSheet(
      h2: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 17,
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
      h3: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      p: TextStyle(
        color: theme.colorScheme.onSurface.withOpacity(0.85),
        fontSize: 14,
        height: 1.6,
      ),
      strong: TextStyle(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.bold,
      ),
      listBullet: TextStyle(
        color: theme.colorScheme.onSurface.withOpacity(0.85),
        fontSize: 14,
        height: 1.6,
      ),
      code: TextStyle(
        color: AppColors.secondary,
        backgroundColor: theme.scaffoldBackgroundColor,
        fontFamily: 'monospace',
        fontSize: 13,
      ),
      codeblockDecoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      blockquoteDecoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Blinking Cursor
// ═══════════════════════════════════════════════════════════
class _BlinkingCursor extends StatefulWidget {
  final Color color;
  const _BlinkingCursor({required this.color});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2,
        height: 16,
        color: widget.color,
      ),
    );
  }
}