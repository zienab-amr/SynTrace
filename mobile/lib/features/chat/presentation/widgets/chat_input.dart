import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';

class ChatInput extends StatefulWidget {
  final Function(String) onSend;
  final bool enabled;
  final bool isLoading;

  const ChatInput({
    super.key,
    required this.onSend,
    this.enabled = true,
    this.isLoading = false,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isLoading || !widget.enabled) return;

    widget.onSend(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSend = _hasText && widget.enabled && !widget.isLoading;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled && !widget.isLoading,
                  maxLines: null,
                  minLines: 1,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.enabled
                        ? 'Ask about your engineering data, risks, developers, PRs...'
                        : 'Connecting...',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                      fontSize: 14,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _buildSendButton(canSend, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton(bool canSend, ThemeData theme) {
    return Material(
      color: canSend ? AppColors.primary : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: canSend ? _handleSend : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: canSend
                ? null
                : theme.colorScheme.onSurface.withOpacity(0.05),
          ),
          child: widget.isLoading
              ? const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : Icon(
                  Icons.arrow_upward_rounded,
                  color: canSend
                      ? Colors.white
                      : theme.colorScheme.onSurface.withOpacity(0.3),
                  size: 20,
                ),
        ),
      ),
    );
  }
}