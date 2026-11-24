import 'package:flutter/material.dart';
import '../../cubit/meeting_notes_state.dart';

class MeetingDetailsError extends StatelessWidget {
  final MeetingNotesState state;
  final VoidCallback onRetry;
  const MeetingDetailsError({
    super.key,
    required this.state,
    required this.onRetry,
  });
  @override
  Widget build(BuildContext context) => _buildErrorState(context, state);

  Widget _buildErrorState(BuildContext context, MeetingNotesState state) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: theme.colorScheme.error,
            ),

            const SizedBox(height: 16),

            Text('Unable to load meeting', style: theme.textTheme.titleMedium),

            const SizedBox(height: 8),

            Text(
              state.detailsRefreshError ??
                  state.errorMessage ??
                  'Something went wrong.',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
