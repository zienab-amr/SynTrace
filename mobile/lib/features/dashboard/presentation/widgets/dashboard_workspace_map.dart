import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/theme/app_theme_extension.dart';
import 'package:syntrace/core/theme/app_premium_icons.dart';
import 'package:syntrace/shared/widgets/app_icon.dart';
import 'package:syntrace/shared/widgets/logo_mark.dart';

import '../painters/workspace_map_painter.dart';

class DashboardWorkspaceMap extends StatefulWidget {
  final int? projectCount;

  const DashboardWorkspaceMap({super.key, required this.projectCount});

  @override
  State<DashboardWorkspaceMap> createState() => _DashboardWorkspaceMapState();
}

class _DashboardWorkspaceMapState extends State<DashboardWorkspaceMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isCompleted && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant DashboardWorkspaceMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.projectCount != widget.projectCount) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final text = context.appText;

    final count = widget.projectCount;

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Workspace map',
                    style: text.titleSmall?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'View projects',
                  onPressed: () => context.go(AppRoutes.projects),
                  icon: AppIcon(
                    AppPremiumIcons.forward,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
            if (count == null)
              const _MapMessage(message: 'Project data is unavailable.')
            else if (count == 0)
              const _MapMessage(message: 'No projects in this workspace yet.')
            else ...[
              Semantics(
                label: 'Workspace with $count available projects',
                child: ExcludeSemantics(
                  child: SizedBox(
                    height: 205,
                    width: double.infinity,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: WorkspaceMapPainter(
                          primary: scheme.primary,
                          surface: colors.surface,
                          projectCount: count,
                          animation: _controller,
                        ),
                        child: const Center(child: LogoMark(size: 25)),
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: Text(
                  count > WorkspaceMapPainter.maxVisibleNodes
                      ? 'Showing 8 of $count projects'
                      : '$count available ${count == 1 ? 'project' : 'projects'}',
                  style: text.bodySmall?.copyWith(
                    fontSize: 11,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _MapMessage extends StatelessWidget {
  final String message;

  const _MapMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      width: double.infinity,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: context.appText.bodySmall?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
