import 'package:flutter/material.dart';
import '../details/overview/project_unavailable_tab.dart';

class BugsListView extends StatelessWidget {
  const BugsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProjectUnavailableTab(
      icon: Icons.bug_report,
      title: 'Bugs unavailable',
      message: 'Bug data is not available from the server.',
    );
  }
}
