import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/chat/data/models/chat_message.dart';
import 'package:syntrace/features/chat/presentation/widgets/ai_progress_steps.dart';
import 'package:syntrace/features/chat/presentation/widgets/jira_cards_list.dart';

import 'chat_sources_list.dart';

import 'package:syntrace/features/meetings/data/repositories/meeting_contract_repository.dart';
import 'package:syntrace/features/meetings/presentation/screens/meeting_contract_screen.dart';

class MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;
  final Function(String newText)? onEdit;
  final Function(String quotedText)? onReply;
  final ValueChanged<String>? onChoice;

  const MessageBubble({
    super.key,
    required this.message,
    this.onRetry,
    this.onDelete,
    this.onEdit,
    this.onReply,
    this.onChoice,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  String _selectedText = '';

  TextDirection _getDirectionality(String text) =>
      Bidi.startsWithRtl(text) ? TextDirection.rtl : TextDirection.ltr;

  Future<void> _copyMessage() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.message.content));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message copied')));
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not copy the message')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == ChatRole.user;

    return SelectionArea(
      onSelectionChanged: (content) {
        _selectedText = content?.plainText ?? '';
      },
      contextMenuBuilder: (context, selectableRegionState) {
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: selectableRegionState.contextMenuAnchors,
          buttonItems: [
            ...selectableRegionState.contextMenuButtonItems,
            if (widget.onReply != null)
              ContextMenuButtonItem(
                label: 'Reply',
                onPressed: () {
                  final text = _selectedText.trim();
                  selectableRegionState.hideToolbar();
                  if (text.isNotEmpty) widget.onReply!(text);
                },
              ),
          ],
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isUser && widget.message.steps.isNotEmpty) ...[
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.85,
                ),
                child: AiProgressSteps(steps: widget.message.steps),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: isUser
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                if (isUser &&
                    widget.message.hasError &&
                    widget.onRetry != null) ...[
                  _buildFailedIcon(context),
                  const SizedBox(width: 8),
                ],
                if (isUser && widget.onEdit != null) ...[
                  IconButton(
                    tooltip: 'Edit message',
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                    onPressed: () => _showEditDialog(context),
                  ),
                  const SizedBox(width: 4),
                ],
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
            if (widget.message.content.trim().isNotEmpty &&
                !widget.message.isStreaming)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.onReply != null)
                    IconButton(
                      tooltip: 'Reply to message',
                      icon: const Icon(Icons.reply, size: 18),
                      onPressed: () => widget.onReply!(widget.message.content),
                    ),
                  IconButton(
                    tooltip: 'Copy message',
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    onPressed: _copyMessage,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.message.content);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Message'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                if (widget.onEdit != null) {
                  widget.onEdit!(controller.text.trim());
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFailedIcon(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Options',
      onSelected: (value) {
        if (value == 'retry') widget.onRetry?.call();
        if (value == 'delete') widget.onDelete?.call();
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
        child: const Icon(Icons.priority_high, color: Colors.white, size: 14),
      ),
    );
  }

  Widget _buildUserBubble(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: widget.message.hasError
            ? AppColors.error.withValues(alpha: 0.7)
            : AppColors.primary,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message.quotedExcerpts.isNotEmpty) ...[
            ...widget.message.quotedExcerpts.map(
              (q) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(
                    left: BorderSide(color: Colors.white70, width: 3),
                  ),
                ),
                child: Text(
                  q,
                  textDirection: _getDirectionality(q),
                  textAlign: TextAlign.start,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            widget.message.content,
            textDirection: _getDirectionality(widget.message.content),
            textAlign: TextAlign.start,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiBubble(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.message.hasError) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 18),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                widget.message.content,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message.content.isEmpty && widget.message.isStreaming)
            Row(children: [_BlinkingCursor(color: theme.colorScheme.onSurface)])
          else if (widget.message.content.isNotEmpty)
            Directionality(
              textDirection: _getDirectionality(widget.message.content),
              child: MarkdownBody(
                data: widget.message.content,
                selectable: false,
                softLineBreak: true,
                styleSheet: _markdownStyle(theme),
              ),
            ),
          if (widget.message.isStreaming &&
              widget.message.content.isNotEmpty) ...[
            const SizedBox(height: 4),
            _BlinkingCursor(color: theme.colorScheme.onSurface),
          ],
          if (!widget.message.isStreaming &&
              widget.message.choices.isNotEmpty &&
              widget.onChoice != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final choice in widget.message.choices)
                  OutlinedButton(
                    onPressed: () => widget.onChoice!(choice),
                    child: Text(choice),
                  ),
              ],
            ),
          ],
          if (MeetingContractRepository.enabled &&
              !widget.message.isStreaming &&
              widget.message.meetingSourceId != null)
            OutlinedButton.icon(
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Open meeting review'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MeetingContractScreen(
                    initialMeetingId: widget.message.meetingSourceId,
                  ),
                ),
              ),
            ),
          if (widget.message.sources.isNotEmpty) ...[
            const SizedBox(height: 12),
            ChatSourcesList(sources: widget.message.sources),
          ] else if (widget.message.jiraCards.isNotEmpty) ...[
            const SizedBox(height: 12),
            JiraCardsList(cards: widget.message.jiraCards),
          ],
        ],
      ),
    );
  }

  MarkdownStyleSheet _markdownStyle(ThemeData theme) {
    return MarkdownStyleSheet(
      textAlign: WrapAlignment.start,
      h1Align: WrapAlignment.start,
      h2Align: WrapAlignment.start,
      h3Align: WrapAlignment.start,
      listBulletPadding: const EdgeInsets.only(left: 0, right: 8),
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
        color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
        fontSize: 14,
        height: 1.6,
      ),
      strong: TextStyle(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.bold,
      ),
      listBullet: TextStyle(
        color: AppColors.primary,
        fontSize: 14,
        height: 1.6,
        fontWeight: FontWeight.bold,
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
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          right: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
    );
  }
}

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
      child: Container(width: 2, height: 16, color: widget.color),
    );
  }
}
