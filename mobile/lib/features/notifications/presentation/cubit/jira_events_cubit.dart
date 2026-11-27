import 'package:flutter_bloc/flutter_bloc.dart';

import 'jira_events_state.dart';

class JiraEventsCubit extends Cubit<JiraEventsState> {
  JiraEventsCubit() : super(JiraEventsInitial());

  Future<void> loadEvents() async {
    if (isClosed) return;

    emit(const JiraEventsUnavailable());
  }
}
