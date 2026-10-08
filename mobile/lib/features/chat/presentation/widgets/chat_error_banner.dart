import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/chat/data/models/chat_error.dart';

class ChatErrorBanner extends StatelessWidget 
{
  final ChatError error;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const ChatErrorBanner({
    super.key,
    required this.error,
    this.onRetry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context)
  {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: AppColors.error.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          // ─── Icon ───
          Icon(
            _getIcon(),
            color: AppColors.error,
            size: 18,
          ),
          const SizedBox(width: 12),

          // ─── Message ───
          Expanded(
            child: Text(
              error.message,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // ─── Retry ───
          if (error.canRetry && onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // ─── Dismiss ───
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: Icon(
                Icons.close,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                size: 18,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Dismiss',
            ),
        ],
      ),
    );
  }

  IconData _getIcon()
  {
    switch (error.type)
    {
      case ChatErrorType.network:
        return Icons.wifi_off;
      case ChatErrorType.server:
        return Icons.cloud_off;
      case ChatErrorType.timeout:
        return Icons.schedule;
      case ChatErrorType.emptyResponse:
        return Icons.chat_bubble_outline;
      case ChatErrorType.unauthorized:
        return Icons.lock_outline;
      case ChatErrorType.unknown:
        return Icons.error_outline;
    }
  }
}