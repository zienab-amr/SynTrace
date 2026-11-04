import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/features/notifications/data/models/mock/mock_jira_events.dart';
import 'package:syntrace/features/notifications/presentation/cubit/jira_events_state.dart';

class JiraEventsCubit extends Cubit<JiraEventsState> {
  JiraEventsCubit() : super(JiraEventsInitial());

  Future<void> loadEvents() async {
    emit(JiraEventsLoading());
    await Future.delayed(const Duration(milliseconds: 500));
    final events = MockJiraEvents.getEvents();
    emit(JiraEventsLoaded(events));
  }
}