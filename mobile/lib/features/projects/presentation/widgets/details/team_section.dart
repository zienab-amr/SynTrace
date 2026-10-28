import 'package:flutter/material.dart';
import 'package:syntrace/features/projects/data/mock_projects.dart';

class TeamSection extends StatelessWidget {
  final List<String> memberIds;

  const TeamSection({super.key, required this.memberIds});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final members = MockUsers.getByIds(memberIds);

    if (members.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'No team members',
          style: TextStyle(color: onSurface.withOpacity(0.6)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.5),
        ),
      ),
      child: Column(
        children: [
          // ─── Header ───
          Row(
            children: [
              Text(
                'Members',
                style: TextStyle(
                  color: onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${members.length}',
                style: TextStyle(
                  color: onSurface.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: theme.dividerColor),

          // ─── Names List ───
          ...members.map((user) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      user.name,
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    user.role.value,
                    style: TextStyle(
                      color: onSurface.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}