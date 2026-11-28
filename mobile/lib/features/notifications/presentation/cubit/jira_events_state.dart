import 'package:syntrace/core/state/base_state.dart';

import '../../data/models/jira_event_model.dart';

abstract class JiraEventsState extends BaseState {
  const JiraEventsState();
}

class JiraEventsInitial extends JiraEventsState {}

class JiraEventsLoading extends JiraEventsState {}

class JiraEventsLoaded extends JiraEventsState {
  final List<JiraEventModel> events;

  const JiraEventsLoaded(this.events);

  @override
  List<Object?> get props => [events];
}

class JiraEventsUnavailable extends JiraEventsState {
  const JiraEventsUnavailable();
}

class JiraEventsError extends JiraEventsState {
  final String message;

  const JiraEventsError(this.message);

  @override
  List<Object?> get props => [message];
}
