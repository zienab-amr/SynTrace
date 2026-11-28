import 'package:flutter/material.dart';

/// A dialog with one text field. It owns its controller, so the text field is never used after
/// the controller is disposed while the dialog animates out. Pops with the trimmed text.
class TextEditDialog extends StatefulWidget {
  const TextEditDialog({
    super.key,
    required this.title,
    required this.label,
    required this.action,
    required this.maxLength,
    this.initialText = '',
    this.helperText,
    this.minLines = 2,
    this.maxLines = 6,
  });

  final String title;
  final String label;
  final String action;
  final int maxLength;
  final String initialText;
  final String? helperText;
  final int minLines;
  final int maxLines;

  static Future<String?> show(BuildContext context, TextEditDialog dialog) =>
      showDialog<String>(context: context, builder: (_) => dialog);

  @override
  State<TextEditDialog> createState() => _TextEditDialogState();
}

class _TextEditDialogState extends State<TextEditDialog> {
  late final _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: Text(widget.action),
      ),
    ],
  );
}
