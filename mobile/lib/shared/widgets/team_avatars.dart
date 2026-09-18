import 'package:flutter/material.dart';
import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/shared/widgets/user_avatar.dart';

/// ═══════════════════════════════════════════════════════════
/// TeamAvatars
/// 
/// مجموعة Avatars متراكبة (Overlapping)
/// كل Avatar له Tooltip بالاسم الكامل
/// ═══════════════════════════════════════════════════════════
class TeamAvatars extends StatelessWidget {
  final List<UserModel> users;
  final int maxVisible;
  final double size;

  const TeamAvatars({
    super.key,
    required this.users,
    this.maxVisible = 3,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const SizedBox.shrink();

    final visibleUsers = users.take(maxVisible).toList();
    final remaining = users.length - maxVisible;
    final overlap = size * 0.7;
    final totalWidth = (overlap * visibleUsers.length) +
        (remaining > 0 ? overlap : 0) +
        (size - overlap);

    return SizedBox(
      height: size,
      width: totalWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ─── المستخدمين الظاهرين ───
          ...List.generate(visibleUsers.length, (index) {
            return Positioned(
              left: index * overlap,
              child: _BorderedAvatar(
                user: visibleUsers[index],
                size: size,
              ),
            );
          }),

          // ─── العدد المتبقي ───
          if (remaining > 0)
            Positioned(
              left: visibleUsers.length * overlap,
              child: _RemainingCount(
                count: remaining,
                size: size,
                users: users.skip(maxVisible).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Avatar مع حدود + Tooltip
// ═══════════════════════════════════════════════════════════
class _BorderedAvatar extends StatelessWidget {
  final UserModel user;
  final double size;

  const _BorderedAvatar({required this.user, required this.size});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: '${user.name}\n${user.role.value}',
      waitDuration: const Duration(milliseconds: 300),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.surface,
            width: 2,
          ),
        ),
        child: UserAvatar(user: user, size: size - 4),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// +N للأشخاص المتبقيين
// ═══════════════════════════════════════════════════════════
class _RemainingCount extends StatelessWidget {
  final int count;
  final double size;
  final List<UserModel> users;

  const _RemainingCount({
    required this.count,
    required this.size,
    required this.users,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final tooltipMessage = users.map((u) => u.name).join('\n');

    return Tooltip(
      message: tooltipMessage,
      waitDuration: const Duration(milliseconds: 300),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.onSurface.withOpacity(0.1),
          border: Border.all(
            color: theme.colorScheme.surface,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            '+$count',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              fontSize: size * 0.32,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}