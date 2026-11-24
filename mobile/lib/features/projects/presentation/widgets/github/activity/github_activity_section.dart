import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/services/current_user_service.dart';

import '../../../../data/models/github_activity_model.dart';
import '../../../cubit/github_activity/github_activity_cubit.dart';
import '../../../cubit/github_activity/github_activity_state.dart';

import 'github_activity_list.dart';
import 'github_activity_details.dart';

class GitHubActivitySection extends StatelessWidget {
  final String projectId;
  final GitHubActivityKind kind;

  const GitHubActivitySection({
    super.key,
    required this.projectId,
    required this.kind,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: CurrentUserService.instance.userNotifier,
      builder: (context, user, _) {
        if (user == null || projectId.isEmpty) {
          return const Center(child: Text('Activity unavailable.'));
        }

        final identity = '${user.id}-${user.tenantId}-${user.role}';

        return BlocProvider(
          key: ValueKey('$identity-$projectId-${kind.apiValue}'),
          create: (_) =>
              GitHubActivityCubit(projectId: projectId, kind: kind)
                ..loadActivity(),
          child: _ActivityContent(kind: kind, identity: identity),
        );
      },
    );
  }
}

class _ActivityContent extends StatelessWidget {
  final GitHubActivityKind kind;
  final String identity;

  const _ActivityContent({required this.kind, required this.identity});

  Future<void> _openDetails(
    BuildContext context,
    GitHubActivityItem item,
  ) async {
    final cubit = context.read<GitHubActivityCubit>();
    final bindingId = cubit.state.source?.bindingId;

    if (bindingId == null || cubit.state.isBusy) {
      return;
    }

    // Verify access before displaying details.
    await cubit.refresh();

    if (!context.mounted || cubit.isClosed) return;

    final state = cubit.state;

    if (state.status != GitHubActivityStatus.success ||
        state.source?.bindingId != bindingId) {
      return;
    }

    GitHubActivityItem? currentItem;

    for (final candidate in state.items) {
      if (candidate.id == item.id) {
        currentItem = candidate;
        break;
      }
    }

    if (currentItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activity is no longer in the refreshed list.'),
        ),
      );

      return;
    }

    final verifiedItem = currentItem;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ProtectedActivityDetails(
          identity: identity,
          item: verifiedItem,
          cubit: cubit,
          bindingId: bindingId,
        ),
      ),
    );

    if (!context.mounted || cubit.isClosed) return;

    await cubit.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return GitHubActivityList(
      kind: kind,
      onItemTap: (item) => _openDetails(context, item),
    );
  }
}

class _ProtectedActivityDetails extends StatefulWidget {
  final String identity;
  final GitHubActivityItem item;
  final GitHubActivityCubit cubit;
  final Object bindingId;

  const _ProtectedActivityDetails({
    required this.identity,
    required this.item,
    required this.cubit,
    required this.bindingId,
  });

  @override
  State<_ProtectedActivityDetails> createState() =>
      _ProtectedActivityDetailsState();
}

class _ProtectedActivityDetailsState extends State<_ProtectedActivityDetails>
    with WidgetsBindingObserver {
  bool _verifying = false;
  bool _accessDenied = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    CurrentUserService.instance.userNotifier.addListener(_checkIdentity);
  }

  bool get _hasSameIdentity {
    final user = CurrentUserService.instance.userNotifier.value;

    if (user == null) return false;

    return '${user.id}-${user.tenantId}-${user.role}' == widget.identity;
  }

  void _checkIdentity() {
    if (!_hasSameIdentity) {
      _denyAccess();
    }
  }

  void _denyAccess() {
    if (!mounted || _accessDenied) return;

    setState(() {
      _accessDenied = true;
      _verifying = false;
    });

    if (ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _verifyAccess() async {
    if (!mounted || _accessDenied || _verifying) {
      return;
    }

    if (!_hasSameIdentity || widget.cubit.isClosed) {
      _denyAccess();
      return;
    }

    setState(() {
      _verifying = true;
    });

    await widget.cubit.refresh();

    if (!mounted) return;

    if (widget.cubit.isClosed || !_hasSameIdentity) {
      _denyAccess();
      return;
    }

    final state = widget.cubit.state;

    final itemStillAvailable = state.items.any(
      (item) => item.id == widget.item.id,
    );

    if (state.status != GitHubActivityStatus.success ||
        state.source?.bindingId != widget.bindingId ||
        !itemStillAvailable) {
      _denyAccess();
      return;
    }

    setState(() {
      _verifying = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verifyAccess();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    CurrentUserService.instance.userNotifier.removeListener(_checkIdentity);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_accessDenied || !_hasSameIdentity) {
      return Scaffold(
        appBar: AppBar(title: const Text('Activity')),
        body: const Center(child: Text('Activity access unavailable.')),
      );
    }

    if (_verifying) {
      return Scaffold(
        appBar: AppBar(title: const Text('Activity')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return BlocBuilder<GitHubActivityCubit, GitHubActivityState>(
      bloc: widget.cubit,
      builder: (context, state) {
        if (state.status != GitHubActivityStatus.success ||
            state.source?.bindingId != widget.bindingId) {
          return Scaffold(
            appBar: AppBar(title: const Text('Activity')),
            body: const Center(child: Text('Activity access unavailable.')),
          );
        }

        for (final item in state.items) {
          if (item.id == widget.item.id) {
            return GitHubActivityDetails(item: item);
          }
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Activity')),
          body: const Center(child: Text('Activity no longer available.')),
        );
      },
    );
  }
}
