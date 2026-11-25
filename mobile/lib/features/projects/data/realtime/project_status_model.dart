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
    return ProjectStatusModel(
      projectId: json['projectId'] as String,
      state: json['state'] as String,
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
