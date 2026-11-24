import 'package:flutter/material.dart';

class MeetingRefreshBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const MeetingRefreshBanner({super.key, required this.message, this.onRetry});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unable to refresh meetings',
            style: TextStyle(
              color: colors.onErrorContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$message Showing last loaded information.',
            style: TextStyle(color: colors.onErrorContainer),
          ),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
