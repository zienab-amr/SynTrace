import 'package:flutter/material.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import 'package:syntrace/features/employees/data/models/employee_model.dart';
import 'package:syntrace/features/profile/data/profile_data_service.dart';
import 'package:syntrace/shared/widgets/layouts/app_page_scaffold.dart';

class EmployeeProfileScreen extends StatefulWidget {
  final String employeeId;
  const EmployeeProfileScreen({super.key, required this.employeeId});
  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  late Future<({EmployeeModel employee, bool cached})> _future;
  CacheSessionGuard? _guard;
  void _load() {
    final scope = CacheScope.fromCurrentUser();
    _guard = scope == null ? null : CacheSessionGuard.capture(scope);
    _future = ProfileDataService.getProfileData(widget.employeeId);
  }

  @override
  void initState() {
    super.initState();
    CurrentUserService.instance.userNotifier.addListener(_sessionChanged);
    _load();
  }

  void _sessionChanged() {
    if (mounted && _guard?.isValid != true) setState(() {});
  }

  @override
  void dispose() {
    CurrentUserService.instance.userNotifier.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EmployeeProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.employeeId != widget.employeeId) _load();
  }

  @override
  Widget build(BuildContext context) => AppPageScaffold(
    title: 'Employee Profile',
    showBackButton: true,
    child: FutureBuilder<({EmployeeModel employee, bool cached})>(
      future: _future,
      builder: (context, snapshot) {
        if (_guard?.isValid != true) {
          return const Center(
            child: Text('Session unavailable. Reopen this page.'),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_guard?.isValid != true || snapshot.hasError || !snapshot.hasData) {
          return Column(
            children: [
              const Text('Profile unavailable'),
              TextButton(
                onPressed: () => setState(_load),
                child: const Text('Retry'),
              ),
            ],
          );
        }
        final employee = snapshot.data!.employee;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (snapshot.data!.cached) const Text('Saved data · Read only'),
            ListTile(
              leading: CircleAvatar(child: Text(employee.initials)),
              title: Text(employee.fullName),
              subtitle: Text(employee.email),
            ),
            if (employee.phoneNumber?.isNotEmpty == true)
              ListTile(
                title: const Text('Phone'),
                subtitle: Text(employee.phoneNumber!),
              ),
            ListTile(
              title: const Text('Workspace roles'),
              subtitle: Text(employee.role),
            ),
            const Divider(),
            const Text(
              'Project assignments and activity are not available yet.',
            ),
          ],
        );
      },
    ),
  );
}
