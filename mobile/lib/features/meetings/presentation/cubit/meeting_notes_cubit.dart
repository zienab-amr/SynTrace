import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/knowledge_source_model.dart';
import '../../data/repositories/meeting_notes_repository.dart';
import 'meeting_notes_state.dart';
import 'meeting_polling_controller.dart';

class MeetingNotesCubit extends Cubit<MeetingNotesState> {
  final MeetingNotesRepository _repository;

  MeetingNotesCubit({MeetingNotesRepository? repository})
    : _repository = repository ?? MeetingNotesRepository(),
      super(const MeetingNotesState());

  final _polling = MeetingPollingController();

  bool _isPolling = false;
  bool _isFetchingList = false;
  bool _isFetchingDetails = false;

  int _listRevision = 0;
  int _detailsRevision = 0;

  String? _clientId;
  String? _projectId;
  String? _selectedMeetingId;

  void _safeEmit(MeetingNotesState newState) {
    if (!isClosed) emit(newState);
  }

  bool _isAccessError(Object error) {
    if (error is! DioException) return false;

    final code = error.response?.statusCode;

    return code == 401 || code == 403 || code == 404;
  }

  List<KnowledgeSourceSummary> _uniqueMeetings(
    Iterable<KnowledgeSourceSummary> meetings,
  ) {
    final unique = <String, KnowledgeSourceSummary>{};

    for (final meeting in meetings) {
      unique.putIfAbsent(meeting.id, () => meeting);
    }

    return List.unmodifiable(unique.values);
  }

  // Load Meetings

  Future<void> loadMeetings({
    String? clientId,
    String? projectId,
    bool silent = false,
  }) async {
    if (isClosed) return;

    final filtersChanged = _clientId != clientId || _projectId != projectId;

    final revision = ++_listRevision;

    _clientId = clientId;
    _projectId = projectId;
    _isFetchingList = true;

    final preserveData =
        silent &&
        !filtersChanged &&
        state.listStatus == MeetingRequestStatus.success;

    if (!preserveData) {
      _safeEmit(
        state.copyWith(
          meetings: filtersChanged ? [] : null,
          listStatus: MeetingRequestStatus.loading,
          clearError: true,
          clearListRefreshError: true,
        ),
      );
    }

    try {
      final meetings = await _repository.getMeetings(
        clientId: clientId,
        projectId: projectId,
      );

      if (isClosed || revision != _listRevision) return;

      _safeEmit(
        state.copyWith(
          meetings: _uniqueMeetings(meetings),
          listStatus: MeetingRequestStatus.success,
          clearListRefreshError: true,
        ),
      );
    } catch (error) {
      if (isClosed || revision != _listRevision) return;

      final message = MeetingNotesRepository.getErrorMessage(error);

      if (_isAccessError(error)) {
        ++_detailsRevision;
        _isFetchingDetails = false;
        _selectedMeetingId = null;

        _safeEmit(
          state.copyWith(
            meetings: [],
            clearSelectedMeeting: true,
            listStatus: MeetingRequestStatus.failure,
            detailsStatus: MeetingRequestStatus.failure,
            isRefreshingDetails: false,
            errorMessage: message,
            listRefreshError: message,
            detailsRefreshError: message,
          ),
        );
      } else if (preserveData) {
        _safeEmit(state.copyWith(listRefreshError: message));
      } else {
        _safeEmit(
          state.copyWith(
            meetings: [],
            listStatus: MeetingRequestStatus.failure,
            errorMessage: message,
            listRefreshError: message,
          ),
        );
      }
    } finally {
      if (revision == _listRevision) {
        _isFetchingList = false;
      }

      _updatePolling();
    }
  }

  // Refresh Meetings

  Future<void> refreshMeetings() async {
    if (isClosed || state.isRefreshing || _isFetchingList) {
      return;
    }

    _safeEmit(state.copyWith(isRefreshing: true, clearListRefreshError: true));

    try {
      await loadMeetings(
        clientId: _clientId,
        projectId: _projectId,
        silent: true,
      );
    } finally {
      _safeEmit(state.copyWith(isRefreshing: false));
    }
  }

  // Load Clients

  Future<void> loadClients() async {
    if (isClosed || state.isLoadingClients) return;

    _safeEmit(
      state.copyWith(
        clientsStatus: MeetingRequestStatus.loading,
        clearError: true,
      ),
    );

    try {
      final clients = await _repository.getClients();

      if (isClosed) return;

      _safeEmit(
        state.copyWith(
          clients: List.unmodifiable(clients),
          clientsStatus: MeetingRequestStatus.success,
        ),
      );
    } catch (error) {
      _safeEmit(
        state.copyWith(
          clients: [],
          clientsStatus: MeetingRequestStatus.failure,
          errorMessage: MeetingNotesRepository.getErrorMessage(error),
        ),
      );
    }
  }

  // Create Meeting

  Future<KnowledgeSourceSummary?> createMeeting(
    CreateKnowledgeSourceRequest request,
  ) async {
    if (isClosed || state.isMutating) return null;

    _safeEmit(
      state.copyWith(
        createStatus: MeetingRequestStatus.loading,
        clearError: true,
      ),
    );

    try {
      final meeting = await _repository.createMeeting(request);

      if (isClosed) return null;

      ++_listRevision;
      _isFetchingList = false;

      final updatedMeetings = [
        if (_matchesFilters(meeting)) meeting,
        ...state.meetings.where((item) => item.id != meeting.id),
      ];

      _safeEmit(
        state.copyWith(
          meetings: _uniqueMeetings(updatedMeetings),
          createStatus: MeetingRequestStatus.success,
          listStatus: MeetingRequestStatus.success,
        ),
      );

      _updatePolling();

      return meeting;
    } catch (error) {
      _safeEmit(
        state.copyWith(
          createStatus: MeetingRequestStatus.failure,
          errorMessage: MeetingNotesRepository.getErrorMessage(error),
        ),
      );

      return null;
    }
  }

  bool _matchesFilters(KnowledgeSourceSummary meeting) {
    return (_clientId == null || meeting.clientId == _clientId) &&
        (_projectId == null || meeting.projectId == _projectId);
  }

  // Load Meeting Details

  Future<void> loadMeetingDetails(String id, {bool silent = false}) async {
    if (isClosed || id.trim().isEmpty) return;

    final revision = ++_detailsRevision;

    final preserveData =
        silent &&
        state.selectedMeeting?.id == id &&
        state.detailsStatus == MeetingRequestStatus.success;

    _selectedMeetingId = id;
    _isFetchingDetails = true;

    _safeEmit(
      state.copyWith(
        detailsStatus: preserveData
            ? MeetingRequestStatus.success
            : MeetingRequestStatus.loading,
        isRefreshingDetails: preserveData,
        clearSelectedMeeting: !preserveData,
        clearDetailsRefreshError: true,
        clearError: !preserveData,
      ),
    );

    try {
      final details = await _repository.getSourceDetails(id);

      if (isClosed ||
          revision != _detailsRevision ||
          _selectedMeetingId != id) {
        return;
      }

      if (details.id != id || !details.source.isMeeting) {
        throw const FormatException('Unexpected meeting details.');
      }

      final updatedMeetings = state.meetings.map(
        (meeting) => meeting.id == id ? details.source : meeting,
      );

      _safeEmit(
        state.copyWith(
          selectedMeeting: details,
          meetings: _uniqueMeetings(updatedMeetings),
          detailsStatus: MeetingRequestStatus.success,
          isRefreshingDetails: false,
          clearDetailsRefreshError: true,
        ),
      );
    } catch (error) {
      if (isClosed ||
          revision != _detailsRevision ||
          _selectedMeetingId != id) {
        return;
      }

      final message = MeetingNotesRepository.getErrorMessage(error);

      if (_isAccessError(error)) {
        final unauthorized =
            error is DioException && error.response?.statusCode == 401;

        if (unauthorized) {
          ++_listRevision;
          _isFetchingList = false;
        }

        _safeEmit(
          state.copyWith(
            listStatus: unauthorized ? MeetingRequestStatus.failure : null,
            listRefreshError: unauthorized ? message : null,
            meetings: unauthorized
                ? []
                : state.meetings
                      .where((item) => item.id != id)
                      .toList(growable: false),
            clearSelectedMeeting: true,
            detailsStatus: MeetingRequestStatus.failure,
            isRefreshingDetails: false,
            errorMessage: message,
            detailsRefreshError: message,
          ),
        );
      } else if (preserveData) {
        _safeEmit(
          state.copyWith(
            isRefreshingDetails: false,
            detailsRefreshError: message,
          ),
        );
      } else {
        _safeEmit(
          state.copyWith(
            clearSelectedMeeting: true,
            detailsStatus: MeetingRequestStatus.failure,
            isRefreshingDetails: false,
            errorMessage: message,
            detailsRefreshError: message,
          ),
        );
      }
    } finally {
      if (revision == _detailsRevision) {
        _isFetchingDetails = false;
      }

      _updatePolling();
    }
  }

  // Refresh Selected Meeting

  Future<void> refreshSelectedMeeting() async {
    final id = _selectedMeetingId;

    if (isClosed || id == null || _isFetchingDetails) {
      return;
    }

    await loadMeetingDetails(id, silent: true);
  }

  // Retry Extraction

  Future<bool> retryExtraction({
    required String id,
    required int version,
  }) async {
    if (isClosed || state.isMutating) return false;

    final meeting = state.selectedMeeting;

    if (meeting == null ||
        meeting.id != id ||
        meeting.source.version != version ||
        !meeting.canRetry ||
        !state.canUseSelectedMeeting) {
      return false;
    }

    _safeEmit(
      state.copyWith(
        retryStatus: MeetingRequestStatus.loading,
        clearError: true,
      ),
    );

    try {
      await _repository.retryExtraction(id: id, version: version);

      if (isClosed) return false;

      if (_selectedMeetingId == id) {
        await loadMeetingDetails(id);
      }

      await refreshMeetings();

      _safeEmit(state.copyWith(retryStatus: MeetingRequestStatus.success));

      return true;
    } catch (error) {
      if (isClosed) return false;

      final message = MeetingNotesRepository.getErrorMessage(error);

      if (_isAccessError(error) && _selectedMeetingId == id) {
        await loadMeetingDetails(id);
      }

      _safeEmit(
        state.copyWith(
          retryStatus: MeetingRequestStatus.failure,
          errorMessage: message,
        ),
      );

      return false;
    }
  }

  // Delete Meeting

  Future<bool> deleteMeeting(String id) async {
    if (isClosed || state.isMutating || id.trim().isEmpty) {
      return false;
    }

    _safeEmit(
      state.copyWith(
        deleteStatus: MeetingRequestStatus.loading,
        deletingId: id,
        clearError: true,
      ),
    );

    try {
      await _repository.deleteSource(id);

      if (isClosed) return false;

      ++_listRevision;
      _isFetchingList = false;

      final isSelected = _selectedMeetingId == id;

      if (isSelected) {
        ++_detailsRevision;
        _selectedMeetingId = null;
        _isFetchingDetails = false;
      }

      _safeEmit(
        state.copyWith(
          meetings: state.meetings
              .where((meeting) => meeting.id != id)
              .toList(growable: false),
          deleteStatus: MeetingRequestStatus.success,
          listStatus: MeetingRequestStatus.success,
          clearDeletingId: true,
          clearSelectedMeeting: isSelected,
          clearDetailsRefreshError: isSelected,
          isRefreshingDetails: isSelected ? false : null,
          detailsStatus: isSelected ? MeetingRequestStatus.initial : null,
        ),
      );

      _updatePolling();

      return true;
    } catch (error) {
      if (isClosed) return false;

      final message = MeetingNotesRepository.getErrorMessage(error);

      if (_isAccessError(error)) {
        await loadMeetings(clientId: _clientId, projectId: _projectId);

        if (_selectedMeetingId == id) {
          await loadMeetingDetails(id);
        }
      }

      _safeEmit(
        state.copyWith(
          deleteStatus: MeetingRequestStatus.failure,
          clearDeletingId: true,
          errorMessage: message,
        ),
      );

      return false;
    }
  }

  // Automatic Polling

  void _updatePolling() {
    if (isClosed) return;

    final shouldPoll =
        state.hasProcessingMeetings ||
        (state.selectedMeeting?.isProcessing ?? false);

    if (shouldPoll) {
      _polling.start(_pollProcessingStatus);
    } else {
      _polling.stop();
    }
  }

  Future<void> _pollProcessingStatus() async {
    if (isClosed ||
        _isPolling ||
        _isFetchingList ||
        _isFetchingDetails ||
        state.isMutating ||
        state.isRefreshing) {
      return;
    }

    _isPolling = true;

    try {
      if (state.hasProcessingMeetings) {
        await loadMeetings(
          clientId: _clientId,
          projectId: _projectId,
          silent: true,
        );
      }

      if (isClosed || _isFetchingDetails) return;

      final selected = state.selectedMeeting;

      if (selected != null && selected.isProcessing) {
        await loadMeetingDetails(selected.id, silent: true);
      }
    } finally {
      _isPolling = false;
      _updatePolling();
    }
  }

  // Reset State

  void clearSelectedMeeting() {
    ++_detailsRevision;

    _selectedMeetingId = null;
    _isFetchingDetails = false;

    _safeEmit(
      state.copyWith(
        clearSelectedMeeting: true,
        clearDetailsRefreshError: true,
        isRefreshingDetails: false,
        detailsStatus: MeetingRequestStatus.initial,
      ),
    );

    _updatePolling();
  }

  void clearError() {
    _safeEmit(state.copyWith(clearError: true));
  }

  void resetCreateStatus() {
    if (state.isCreating) return;

    _safeEmit(
      state.copyWith(
        createStatus: MeetingRequestStatus.initial,
        clearError: true,
      ),
    );
  }

  @override
  Future<void> close() {
    _polling.stop();

    ++_listRevision;
    ++_detailsRevision;

    return super.close();
  }
}
