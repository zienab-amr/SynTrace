import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/features/dashboard/data/mock/mock_dashboard_data.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit() : super(DashboardInitial());

  Future<void> loadDashboard() async {
    emit(DashboardLoading());

    await Future.delayed(const Duration(milliseconds: 800));

    final stats = MockDashboardData.getStats();
    final activities = MockDashboardData.getRecentActivities();

    emit(DashboardLoaded(stats, activities));
  }
}