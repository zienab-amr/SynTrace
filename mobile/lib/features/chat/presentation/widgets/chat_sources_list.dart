import 'package:flutter/material.dart';
import '../../data/models/chat_source_model.dart';
import 'chat_source_card.dart';

class ChatSourcesList extends StatelessWidget {
  final List<ChatSourceModel> sources;
  const ChatSourcesList({super.key, required this.sources});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sources', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final source in sources) ChatSourceCard(source: source),
      ],
    );
  }
}
