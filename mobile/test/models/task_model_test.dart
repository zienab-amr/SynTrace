import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/core/models/task_model.dart';

void main() {
  group('TaskModel', () {
    test('isOverdue returns true when due date passed and not done', () {
      final task = TaskModel(
        id: '1',
        title: 'Old task',
        status: TaskStatus.todo,
        priority: TaskPriority.high,
        projectId: 'p1',
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(task.isOverdue, isTrue);
    });
  });
}