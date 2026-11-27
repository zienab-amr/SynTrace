import 'package:flutter/material.dart';
import 'package:syntrace/features/chat/data/models/jira_card_model.dart';
import 'package:syntrace/features/chat/presentation/widgets/jira_card_widget.dart';

class JiraCardsList extends StatefulWidget {
  final List<JiraCardModel> cards;

  const JiraCardsList({super.key, required this.cards});

  @override
  State<JiraCardsList> createState() => _JiraCardsListState();
}

class _JiraCardsListState extends State<JiraCardsList> {
  bool _isExpanded = false;
  final int _initialLimit = 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasMore = widget.cards.length > _initialLimit;
    final displayedCards = _isExpanded
        ? widget.cards
        : widget.cards.take(_initialLimit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...displayedCards.map((card) {
          return JiraCardWidget(card: card);
        }),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              icon: Icon(
                _isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 16,
              ),
              label: Text(
                _isExpanded
                    ? 'Show Less'
                    : '+${widget.cards.length - _initialLimit} More',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
      ],
    );
  }
}
