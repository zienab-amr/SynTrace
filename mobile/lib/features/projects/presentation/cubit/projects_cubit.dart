import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/models/project_model.dart';
import 'package:syntrace/features/projects/data/mock_projects.dart';
import 'projects_state.dart';

class ProjectsCubit extends Cubit<ProjectsState> {
  ProjectsCubit() : super(const ProjectsInitial());

  List<ProjectModel> _allProjects = [];
  String _searchQuery = '';
  ProjectStatus? _statusFilter;
  String? _riskFilter;

  Future<void> loadProjects() async {
    emit(const ProjectsLoading());
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      _allProjects = MockProjects.projects;
      _emitFiltered();
    } catch (e) {
      emit(ProjectsError('Failed to load projects: $e'));
    }
  }

  // ═══════════════════════════════════════════════════════
  // Search
  // ═══════════════════════════════════════════════════════
  void search(String query) {
    _searchQuery = query;
    _emitFiltered();
  }

  // ═══════════════════════════════════════════════════════
  // Status Filter
  // ═══════════════════════════════════════════════════════
  void setStatusFilter(ProjectStatus? status) {
    _statusFilter = status;
    _emitFiltered();
  }

  // ═══════════════════════════════════════════════════════
  // Risk Filter
  // ═══════════════════════════════════════════════════════
  void setRiskFilter(String? risk) {
    _riskFilter = risk;
    _emitFiltered();
  }

  // ═══════════════════════════════════════════════════════
  // Clear All
  // ═══════════════════════════════════════════════════════
  void clearFilters() {
    _searchQuery = '';
    _statusFilter = null;
    _riskFilter = null;
    _emitFiltered();
  }

  // ═══════════════════════════════════════════════════════
  // Refresh
  // ═══════════════════════════════════════════════════════
  Future<void> refresh() async {
    await loadProjects();
  }

  // ═══════════════════════════════════════════════════════
  // Internal
  // ═══════════════════════════════════════════════════════
  void _emitFiltered() {
    var filtered = List<ProjectModel>.from(_allProjects);

    // ─── Search ───
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        return p.name.toLowerCase().contains(q) ||
            (p.description?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    // ─── Status ───
    if (_statusFilter != null) {
      filtered = filtered.where((p) => p.status == _statusFilter).toList();
    }

    // ─── Risk ───
    if (_riskFilter != null) {
      filtered = filtered.where((p) {
        final stats = MockProjectStats.forProject(p.id);
        final riskName = stats.risk.name; // high, medium, low
        return riskName == _riskFilter;
      }).toList();
    }

    emit(ProjectsLoaded(
      projects: filtered,
      searchQuery: _searchQuery,
      statusFilter: _statusFilter,
      riskFilter: _riskFilter,
    ));
  }
}