import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';

/// ═══════════════════════════════════════════════════════════
/// DetailOverlay
/// 
/// بيفتح Overlay فيه تفاصيل حاجة معينة
/// - موبايل: Bottom Sheet طالع من تحت
/// - ويب: Modal في النص
/// ═══════════════════════════════════════════════════════════
class DetailOverlay {
  DetailOverlay._();

  static Future<void> show({
    required BuildContext context,
    required String title,
    required Widget child,
    String? subtitle,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      // ─── موبايل: Bottom Sheet ───
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _BottomSheetContent(
          title: title,
          subtitle: subtitle,
          child: child,
        ),
      );
    }

    // ─── ويب: Modal ───
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => _ModalContent(
        title: title,
        subtitle: subtitle,
        child: child,
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════
/// Bottom Sheet Content (Mobile)
/// ═══════════════════════════════════════════════════════════
class _BottomSheetContent extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _BottomSheetContent({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ─── Drag Handle ───
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ─── Header ───
          _OverlayHeader(title: title, subtitle: subtitle),

          // ─── Content ───
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════
/// Modal Content (Web)
/// ═══════════════════════════════════════════════════════════
class _ModalContent extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _ModalContent({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 700,
          maxHeight: 600,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _OverlayHeader(title: title, subtitle: subtitle),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════
/// Header مشترك
/// ═══════════════════════════════════════════════════════════
class _OverlayHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _OverlayHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.close,
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }
}