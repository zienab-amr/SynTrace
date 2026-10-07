import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/chat/data/models/chat_message.dart';
import 'package:syntrace/features/chat/presentation/widgets/ai_progress_steps.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // ─── Steps (لو فيه) ───
          if (!isUser && message.steps.isNotEmpty) ...[
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              child: AiProgressSteps(steps: message.steps),
            ),
            const SizedBox(height: 10),
          ],

          // ─── Bubble ───
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
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
  // User Bubble
  // ═══════════════════════════════════════════════════════
  Widget _buildUserBubble(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
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
  // AI Bubble (Markdown)
  // ═══════════════════════════════════════════════════════
  Widget _buildAiBubble(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarkdownBody(
            data: message.content,
            styleSheet: _markdownStyle(theme),
            selectable: true,
          ),
          if (message.isStreaming) ...[
            const SizedBox(height: 8),
            _BlinkingCursor(color: theme.colorScheme.onSurface),
          ],
        ],
      ),
    );
  }

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