import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/features/settings/presentation/cubit/integrations_cubit.dart';
import 'package:syntrace/features/settings/presentation/cubit/integrations_state.dart';

class JiraCallbackScreen extends StatefulWidget {
  final String status;
  final String? pendingId;

  const JiraCallbackScreen({super.key, required this.status, this.pendingId});

  @override
  State<JiraCallbackScreen> createState() => _JiraCallbackScreenState();
}

class _JiraCallbackScreenState extends State<JiraCallbackScreen> {
  bool _navigated = false;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cubit = context.read<IntegrationsCubit>();
      await cubit.handleJiraCallback(widget.status, widget.pendingId);
    });
  }

  void _goToSettings() {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.go(AppRoutes.settings);
  }

  String _siteName(Map<String, dynamic> s) => (s['name'] ??
          s['siteName'] ??
          s['displayName'] ??
          s['url'] ??
          s['siteUrl'] ??
          'Jira Site')
      .toString();

  String _siteId(Map<String, dynamic> s) =>
      (s['id'] ?? s['cloudId'] ?? s['siteId'] ?? s['value'] ?? '').toString();

  void _showSitesDialog(IntegrationsSiteSelectionRequired state) {
    if (_dialogOpen) return;
    _dialogOpen = true;

    final cubit = context.read<IntegrationsCubit>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Select Jira Site'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: state.sites.length,
              itemBuilder: (context, index) {
                final site = state.sites[index];
                final siteId = _siteId(site);

                return ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(_siteName(site)),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _dialogOpen = false;
                    cubit.completeJiraConnection(
                      state.pendingId,
                      siteId,
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<IntegrationsCubit, IntegrationsState>(
      listener: (context, state) {
        if (state is IntegrationsSiteSelectionRequired) {
          _showSitesDialog(state);
        } else if (state is IntegrationsLoaded) {
          _goToSettings();
        } else if (state is IntegrationsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
          _goToSettings();
        }
      },
      child: const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}