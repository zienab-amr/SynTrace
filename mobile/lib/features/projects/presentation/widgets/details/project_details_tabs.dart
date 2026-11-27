import 'package:flutter/material.dart';

class ProjectDetailsTabs extends StatelessWidget {
  final TabController controller;

  const ProjectDetailsTabs({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,

        labelPadding: const EdgeInsets.symmetric(horizontal: 12),

        indicator: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(7),
        ),

        indicatorSize: TabBarIndicatorSize.tab,

        indicatorPadding: const EdgeInsets.all(4),

        dividerColor: Colors.transparent,

        labelColor: colors.onPrimary,

        unselectedLabelColor: colors.onSurfaceVariant,

        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),

        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),

        tabs: const [
          Tab(text: 'Overview', height: 48),
          Tab(text: 'Tasks', height: 48),
          Tab(text: 'Pull Requests', height: 48),
          Tab(text: 'Commits', height: 48),
          Tab(text: 'Bugs', height: 48),
          Tab(text: 'Team Notes', height: 48),
          Tab(text: 'AI Notes', height: 48),
        ],
      ),
    );
  }
}
