import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/features/projects/data/realtime/project_status_model.dart';

void main() {
  test('parses project status and versions', () {
    final result = ProjectStatusModel.fromJson({
      'projectId': 'project-1',
      'state': 'pending',
      'requestedVersion': 4,
      'completedVersion': 3,
      'lastSuccessAtUtc': '2026-11-27T12:00:00Z',
    });
    expect(result.projectId, 'project-1');
    expect(result.isProcessing, isTrue);
    expect(result.requestedVersion, 4);
    expect(result.completedVersion, 3);
    expect(result.lastSuccessAtUtc?.isUtc, isTrue);
  });

  test('accepts each backend state', () {
    for (final state in ['not-mapped', 'pending', 'retrying', 'synced']) {
      expect(
        ProjectStatusModel.fromJson({
          'projectId': 'project-1',
          'state': state,
        }).state,
        state,
      );
    }
  });

  test('accepts null versions for unmapped project', () {
    final result = ProjectStatusModel.fromJson({
      'projectId': 'project-1',
      'state': 'not-mapped',
    });
    expect(result.isNotMapped, isTrue);
    expect(result.requestedVersion, isNull);
  });

  test('rejects unknown state', () {
    expect(
      () => ProjectStatusModel.fromJson({
        'projectId': 'project-1',
        'state': 'unknown',
      }),
      throwsFormatException,
    );
  });

  test('rejects missing project identifier', () {
    expect(
      () => ProjectStatusModel.fromJson({'state': 'synced'}),
      throwsFormatException,
    );
  });
}
