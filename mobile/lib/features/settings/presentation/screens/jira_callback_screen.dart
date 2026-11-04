import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/features/settings/presentation/cubit/integrations_cubit.dart';

class JiraCallbackScreen extends StatefulWidget {
  final String status;
  final String? pendingId;

  const JiraCallbackScreen({super.key, required this.status, this.pendingId});

  @override
  State<JiraCallbackScreen> createState() => _JiraCallbackScreenState();
}

class _JiraCallbackScreenState extends State<JiraCallbackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cubit = context.read<IntegrationsCubit>();
      await cubit.handleJiraCallback(widget.status, widget.pendingId);
      
      if (mounted) {
        context.go(AppRoutes.settings);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}