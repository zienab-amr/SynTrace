import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/services/local_storage_service.dart';
import '../../data/models/meeting_note_model.dart';
import 'meeting_notes_state.dart';

class MeetingNotesCubit extends Cubit<MeetingNotesState> {
  MeetingNotesCubit() : super(MeetingNotesInitial());

  List<MeetingNote> _meetings = [];

  Future<void> loadMeetings() async {
    emit(MeetingNotesLoading());

    try {
      // بنقرأ الداتا من الستوراج المحلي بس (مفيش موك)
      final localData = await LocalStorageService.instance.loadMeetings();

      if (localData != null && localData.isNotEmpty) {
        _meetings = localData;
      } else {
        _meetings = []; // لو مفيش داتا، بتبدأ فاضية
      }

      emit(MeetingNotesLoaded(List.from(_meetings)));
    } catch (e) {
      _meetings = [];
      emit(MeetingNotesLoaded(List.from(_meetings)));
    }
  }

  Future<void> addMeeting(MeetingNote note) async {
    _meetings.insert(0, note);
    emit(MeetingNotesLoaded(List.from(_meetings)));
    await _saveToLocal();
  }

  Future<void> saveDraft(MeetingNote draft) async {
    final index = _meetings.indexWhere((m) => m.id == draft.id);
    if (index != -1) {
      _meetings[index] = draft;
    } else {
      _meetings.insert(0, draft);
    }
    emit(MeetingNotesLoaded(List.from(_meetings)));
    await _saveToLocal();
  }

  Future<void> deleteMeeting(String id) async {
    _meetings.removeWhere((m) => m.id == id);
    emit(MeetingNotesLoaded(List.from(_meetings)));
    await _saveToLocal();
  }

  Future<void> _saveToLocal() async {
    await LocalStorageService.instance.saveMeetings(_meetings);
  }
}
