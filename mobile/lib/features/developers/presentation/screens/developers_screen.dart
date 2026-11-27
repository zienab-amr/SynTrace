import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/features/developers/presentation/cubit/developers_cubit.dart';
import 'package:syntrace/features/developers/presentation/cubit/developers_state.dart';
import 'package:syntrace/shared/widgets/layouts/app_page_scaffold.dart';

class DevelopersScreen extends StatefulWidget {
  const DevelopersScreen({super.key});
  @override
  State<DevelopersScreen> createState() => _DevelopersScreenState();
}

class _DevelopersScreenState extends State<DevelopersScreen> {
  @override
  void initState() {
    super.initState();
    context.read<DevelopersCubit>().loadDevelopers();
  }

  @override
  Widget build(BuildContext context) => AppPageScaffold(
    title: 'Developers',
    subtitle: 'Engineering team members',
    child: BlocBuilder<DevelopersCubit, DevelopersState>(
      builder: (context, state) {
        if (state is DevelopersLoaded) {
          return Column(
            children: [
              TextButton(
                onPressed: context.read<DevelopersCubit>().loadDevelopers,
                child: const Text('Refresh'),
              ),
              if (state.isFromCache) const Text('Saved data · Read only'),
              if (state.developers.isEmpty) const Text('No developers found.'),
              ...state.developers.map(
                (d) => ListTile(
                  leading: CircleAvatar(child: Text(d.initials)),
                  title: Text(d.name),
                  subtitle: Text('${d.email}\n${d.role}'),
                ),
              ),
            ],
          );
        }
        if (state is DevelopersError) {
          return Column(
            children: [
              Text(state.message),
              TextButton(
                onPressed: context.read<DevelopersCubit>().loadDevelopers,
                child: const Text('Retry'),
              ),
            ],
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    ),
  );
}
