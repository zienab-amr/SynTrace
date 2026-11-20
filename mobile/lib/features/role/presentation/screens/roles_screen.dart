import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/roles_cubit.dart';
import '../cubit/roles_state.dart';

class RolesScreen extends StatefulWidget {
  const RolesScreen({Key? key}) : super(key: key);

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<RolesCubit>().fetchRoles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Roles Management')),
      body: BlocConsumer<RolesCubit, RolesState>(
        listener: (context, state) {
          if (state is RolesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
          if (state is RolesActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is RolesLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is RolesLoaded) {
            if (state.roles.isEmpty) {
              return const Center(child: Text('No Roles Found. Tap + to add.'));
            }
            return ListView.builder(
              itemCount: state.roles.length,
              itemBuilder: (context, index) {
                final role = state.roles[index];
                return ListTile(
                  title: Text(role.name),
                  subtitle: Text(role.description ?? 'No Description'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      context.read<RolesCubit>().deleteRole(role.id);
                    },
                  ),
                );
              },
            );
          }

          return const Center(child: Text('Something went wrong.'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // context.read<RolesCubit>().createRole('Admin', 'Admin Role');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
