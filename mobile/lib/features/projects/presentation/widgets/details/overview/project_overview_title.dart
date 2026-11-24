import 'package:flutter/material.dart';

class ProjectOverviewTitle extends StatelessWidget {
  final String title;
  const ProjectOverviewTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
