class ProjectStatusModel {
  final String projectId;
  final String state;
  final int? requestedVersion;
  final int? completedVersion;
  final DateTime? lastSuccessAtUtc;

  const ProjectStatusModel({
    required this.projectId,
    required this.state,
    this.requestedVersion,
    this.completedVersion,
    this.lastSuccessAtUtc,
  });

  factory ProjectStatusModel.fromJson(Map<String, dynamic> json) {
    final projectId = json['projectId'];
    final state = json['state'];
    if (projectId is! String ||
        projectId.trim().isEmpty ||
        projectId.length > 450 ||
        state is! String ||
        !const {
          'not-mapped',
          'pending',
          'retrying',
          'synced',
        }.contains(state)) {
      throw const FormatException('Invalid project status event.');
    }
    return ProjectStatusModel(
      projectId: projectId,
      state: state,
      requestedVersion: (json['requestedVersion'] as num?)?.toInt(),
      completedVersion: (json['completedVersion'] as num?)?.toInt(),
      lastSuccessAtUtc: DateTime.tryParse(
        json['lastSuccessAtUtc']?.toString() ?? '',
      )?.toUtc(),
    );
  }

  bool get isPending => state == 'pending';

  bool get isRetrying => state == 'retrying';

  bool get isSynced => state == 'synced';

  bool get isNotMapped => state == 'not-mapped';

  bool get isProcessing => isPending || isRetrying;
}
