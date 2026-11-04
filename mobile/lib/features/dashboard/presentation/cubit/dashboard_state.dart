import 'package:syntrace/core/state/base_state.dart';
import '../../data/models/dashboard_models.dart';

abstract class DashboardState extends BaseState {
  const DashboardState();
}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final DashboardStats stats;
  final List<RecentActivity> activities;

  const DashboardLoaded(this.stats, this.activities);

  @override
  List<Object?> get props => [stats, activities];
}