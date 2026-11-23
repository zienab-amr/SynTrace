import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syntrace/core/theme/app_colors.dart';

class ChatInput extends StatefulWidget {
  final Function(String, List<String>) onSend;
  final bool enabled;
  final bool isLoading;

  const ChatInput({
    super.key,
    required this.onSend,
    this.enabled = true,
    this.isLoading = false,
  });

  @override
  State<ChatInput> createState() => ChatInputState();
}

class ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  List<String> _quotedTexts = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void addQuote(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      if (!_quotedTexts.contains(text)) {
        _quotedTexts.add(text);
      }
    });
    _focusNode.requestFocus();
  }

  void _removeQuote(int index) {
    setState(() {
      _quotedTexts.removeAt(index);
    });
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;

    widget.onSend(text, _quotedTexts);
    _controller.clear();
    setState(() => _quotedTexts = []);
    _focusNode.requestFocus();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      if (!HardwareKeyboard.instance.isShiftPressed) {
        _handleSend();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSend = _hasText && widget.enabled;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_quotedTexts.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.format_quote, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Replying to ${_quotedTexts.length} excerpt(s)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => setState(() => _quotedTexts = []),
                          child: Icon(Icons.close, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quotedTexts.asMap().entries.map((entry) {
                        return Chip(
                          label: Text(
                            entry.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () => _removeQuote(entry.key),
                          backgroundColor: theme.scaffoldBackgroundColor,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Focus(
                      onKeyEvent: _handleKeyEvent,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        enabled: widget.enabled,
                        maxLines: null,
                        minLines: 1,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: widget.enabled
                              ? 'Ask about your engineering data...'
                              : 'Connecting...',
                          hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4), fontSize: 14),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _buildSendButton(canSend, theme),
                ],
              ),
            ),
          ],
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
            color: canSend ? null : theme.colorScheme.onSurface.withOpacity(0.05),
          ),
          child: Icon(
            Icons.arrow_upward_rounded,
            color: canSend ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.3),
            size: 20,
          ),
        ),
      ),
    );
  }
}