
import 'package:syntrace/core/state/base_state.dart';
import 'package:syntrace/features/notifications/data/models/jira_event_model.dart';

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