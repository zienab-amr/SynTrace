import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import 'package:syntrace/core/services/current_user_service.dart';

class ClientSessionBoundary extends StatefulWidget {
  final Widget child;
  final CacheSessionGuard guard;
  final DateTime expiresAt;
  final bool Function()? canDisplay;
  const ClientSessionBoundary({
    super.key,
    required this.child,
    required this.guard,
    required this.expiresAt,
    this.canDisplay,
  });
  @override
  State<ClientSessionBoundary> createState() => _ClientSessionBoundaryState();
}

class _ClientSessionBoundaryState extends State<ClientSessionBoundary> {
  Timer? _timer;
  bool _revoked = false;
  bool get _valid =>
      !_revoked &&
      widget.guard.isValid &&
      DateTime.now().toUtc().isBefore(widget.expiresAt) &&
      (widget.canDisplay?.call() ?? true);
  @override
  void initState() {
    super.initState();
    CurrentUserService.instance.userNotifier.addListener(_check);
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _check());
  }

  void _check() {
    if (mounted && !_valid && !_revoked) setState(() => _revoked = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    CurrentUserService.instance.userNotifier.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _valid
      ? widget.child
      : AlertDialog(
          title: const Text('Client data unavailable'),
          content: const Text('Close this dialog and refresh your workspace.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
}

CacheSessionGuard captureClientSession() {
  final scope = CacheScope.fromCurrentUser();
  if (scope == null) throw StateError('Session unavailable.');
  return CacheSessionGuard.capture(scope);
}
