import 'package:flutter/material.dart';
import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  final UserModel? user;
  final double size;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    required this.user,
    this.size = 36,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initials = user?.initials ?? '?';
    final avatarUrl = user?.avatarUrl;
    final hasImage = avatarUrl != null && avatarUrl.isNotEmpty;

    final avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: backgroundColor ?? AppColors.primary,
      backgroundImage: hasImage ? NetworkImage(avatarUrl) : null,
      child: hasImage
          ? null
          : Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.35,
                fontWeight: FontWeight.w600,
              ),
            ),
    );

    if (onTap == null) return avatar;

    return GestureDetector(
      onTap: onTap,
      child: avatar,
    );
  }
}