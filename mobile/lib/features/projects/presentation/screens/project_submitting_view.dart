part of 'create_project_screen.dart';

class _ProjectSubmittingView extends StatelessWidget {
  final bool projectCreated;

  final int completedMembers;
  final int totalMembers;

  const _ProjectSubmittingView({
    required this.projectCreated,
    required this.completedMembers,
    required this.totalMembers,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),

            const SizedBox(height: 24),

            Text(
              projectCreated
                  ? 'Configuring your project'
                  : 'Creating your project',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),

            const SizedBox(height: 12),

            Text(
              projectCreated
                  ? 'Team assignments: '
                        '$completedMembers/$totalMembers'
                  : 'Setting up your workspace...',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),

            const SizedBox(height: 8),

            Text(
              'Please keep this screen open.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
