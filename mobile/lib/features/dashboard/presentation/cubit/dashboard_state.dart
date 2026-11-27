import 'package:syntrace/core/state/base_state.dart';

import '../../data/models/dashboard_models.dart';

abstract class DashboardState extends BaseState {
  const DashboardState();
}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final DashboardData data;

  final bool isRefreshing;
  final bool isFromCache;

  const DashboardLoaded({
    required this.data,
    this.isRefreshing = false,
    this.isFromCache = false,
  });

  @override
  List<Object?> get props => [data, isRefreshing, isFromCache];
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object?> get props => [message];
}
