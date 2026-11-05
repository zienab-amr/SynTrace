import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';

class ProjectDetailsTabs extends StatelessWidget {
  final TabController controller;

  const ProjectDetailsTabs({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.3),
        ),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Theme.of(
          context,
        ).colorScheme.onSurface.withOpacity(0.6),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        tabs: const [
          Tab(text: 'Overview', height: 36),
          Tab(text: 'Tasks', height: 36),
          Tab(text: 'Pull Requests', height: 36),
          Tab(text: 'Commits', height: 36),
          Tab(text: 'Bugs', height: 36),
          Tab(text: 'Team Notes', height: 36),
          Tab(text: 'AI Notes', height: 36),
        ],
      ),
    );
  }
}
