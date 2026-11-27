import '../widgets/clients/client_session_boundary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/shared/widgets/layouts/app_page_scaffold.dart';
import '../../data/models/project_client_model.dart';
import '../cubit/clients_cubit.dart';
import '../cubit/clients_state.dart';
import '../widgets/create_project/create_client_dialog.dart';
import '../widgets/clients/client_form_dialog.dart';

class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ClientsCubit()..load(),
    child: const _ClientsView(),
  );
}

class _ClientsView extends StatefulWidget {
  const _ClientsView();
  @override
  State<_ClientsView> createState() => _ClientsViewState();
}

class _ClientsViewState extends State<_ClientsView>
    with WidgetsBindingObserver {
  String _query = '';
  ClientStatus? _status;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<ClientsCubit>().load();
    }
  }

  Future<void> _open(ProjectClientModel item, bool cached) async {
    final cubit = context.read<ClientsCubit>();
    final session = CurrentUserService.instance.user;
    final expiry = cubit.state.expiresAt;
    if (expiry == null || !DateTime.now().toUtc().isBefore(expiry)) return;
    final guard = captureClientSession();
    ProjectClientModel client = item;
    if (!cached) {
      try {
        client = await cubit.repository.getClientById(item.id);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to verify client details.')),
          );
        }
        return;
      }
    }
    if (!mounted ||
        !guard.isValid ||
        CurrentUserService.instance.user != session ||
        cubit.state.clients == null) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ClientSessionBoundary(
        guard: guard,
        expiresAt: expiry,
        canDisplay: () =>
            !cubit.isClosed &&
            cubit.state.clients?.any((c) => c.id == client.id) == true,
        child: AlertDialog(
          title: Text(client.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: ${client.status.name}'),
              Text(client.email ?? 'No email'),
              Text(client.phoneNumber ?? 'No phone'),
              if (cached) const Text('Saved data • read only'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            if (!cached && cubit.state.canMutate && session?.isAdmin == true)
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  if (!mounted || !guard.isValid || !cubit.state.canMutate) {
                    return;
                  }
                  await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => ClientSessionBoundary(
                      guard: guard,
                      expiresAt: expiry,
                      child: ClientFormDialog(
                        client: client,
                        repository: cubit.repository,
                        canSubmit: () => guard.isValid && cubit.state.canMutate,
                      ),
                    ),
                  );
                  if (mounted) await cubit.load();
                },
                child: const Text('Edit'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<ClientsCubit, ClientsState>(
    builder: (context, state) {
      final cubit = context.read<ClientsCubit>();
      final canCreate =
          state.canMutate && CurrentUserService.instance.user?.isAdmin == true;
      final items = state.clients
          ?.where(
            (c) =>
                (_status == null || c.status == _status) &&
                c.name.toLowerCase().contains(_query.trim().toLowerCase()),
          )
          .toList();
      return AppPageScaffold(
        title: 'Clients',
        subtitle: 'Manage your organization’s clients',
        scrollable: false,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: state.loading ? null : cubit.load,
            icon: const Icon(Icons.refresh),
          ),
          if (canCreate)
            IconButton(
              tooltip: 'New client',
              icon: const Icon(Icons.add),
              onPressed: () async {
                await CreateClientDialog.show(context);
                if (mounted) await cubit.load();
              },
            ),
        ],
        searchBar: items == null
            ? null
            : TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search clients',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
        filterBar: items == null
            ? null
            : DropdownButton<ClientStatus?>(
                value: _status,
                items: [
                  const DropdownMenuItem<ClientStatus?>(
                    value: null,
                    child: Text('All statuses'),
                  ),
                  ...ClientStatus.values.map(
                    (s) => DropdownMenuItem<ClientStatus?>(
                      value: s,
                      child: Text(s.name),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _status = v),
              ),
        child: Column(
          children: [
            if (state.loading) const LinearProgressIndicator(),
            if (state.cached && items != null)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Saved clients • read only. Refresh to edit.'),
              ),
            if (state.error != null) Text(state.error!),
            Expanded(
              child: items == null
                  ? Center(
                      child: state.loading
                          ? const CircularProgressIndicator()
                          : const Text('Clients unavailable'),
                    )
                  : items.isEmpty
                  ? const Center(child: Text('No matching clients'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final item = items[i];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.business_outlined),
                            title: Text(item.name),
                            subtitle: Text(
                              item.email ??
                                  item.phoneNumber ??
                                  'No contact information',
                            ),
                            trailing: Text(item.status.name),
                            onTap: () =>
                                _open(item, state.cached || state.loading),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    },
  );
}
