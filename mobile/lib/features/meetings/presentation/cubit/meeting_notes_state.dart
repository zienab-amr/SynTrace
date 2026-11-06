import 'package:syntrace/core/state/base_state.dart';
import '../../data/models/meeting_note_model.dart';

abstract class MeetingNotesState extends BaseState {
  const MeetingNotesState();
}

class MeetingNotesInitial extends MeetingNotesState {}

class MeetingNotesLoading extends MeetingNotesState {}

class MeetingNotesLoaded extends MeetingNotesState {
  final List<MeetingNote> meetings;
  const MeetingNotesLoaded(this.meetings);

  @override
  List<Object?> get props => [meetings];
}

class MeetingNotesError extends MeetingNotesState {
  final String message;
  const MeetingNotesError(this.message);

  @override
  List<Object?> get props => [message];
}
