import 'package:equatable/equatable.dart';

import '../../data/models/knowledge_source_model.dart';
import '../../data/models/meeting_client_model.dart';

enum MeetingRequestStatus { initial, loading, success, failure }

class MeetingNotesState extends Equatable {
  final List<KnowledgeSourceSummary> meetings;
  final List<MeetingClientModel> clients;
  final KnowledgeSourceDetails? selectedMeeting;

  final MeetingRequestStatus listStatus;
  final MeetingRequestStatus clientsStatus;
  final MeetingRequestStatus detailsStatus;
  final MeetingRequestStatus createStatus;
  final MeetingRequestStatus deleteStatus;
  final MeetingRequestStatus retryStatus;

  final bool isRefreshing;
  final bool isRefreshingDetails;

  final String? deletingId;
  final String? errorMessage;

  final String? listRefreshError;
  final String? detailsRefreshError;

  const MeetingNotesState({
    this.meetings = const [],
    this.clients = const [],
    this.selectedMeeting,
    this.listStatus = MeetingRequestStatus.initial,
    this.clientsStatus = MeetingRequestStatus.initial,
    this.detailsStatus = MeetingRequestStatus.initial,
    this.createStatus = MeetingRequestStatus.initial,
    this.deleteStatus = MeetingRequestStatus.initial,
    this.retryStatus = MeetingRequestStatus.initial,
    this.isRefreshing = false,
    this.isRefreshingDetails = false,
    this.deletingId,
    this.errorMessage,
    this.listRefreshError,
    this.detailsRefreshError,
  });

  bool get isLoading => listStatus == MeetingRequestStatus.loading;

  bool get isLoadingClients => clientsStatus == MeetingRequestStatus.loading;

  bool get isLoadingDetails => detailsStatus == MeetingRequestStatus.loading;

  bool get isCreating => createStatus == MeetingRequestStatus.loading;

  bool get isDeleting => deleteStatus == MeetingRequestStatus.loading;

  bool get isRetrying => retryStatus == MeetingRequestStatus.loading;

  bool get isMutating => isCreating || isDeleting || isRetrying;

  bool get hasProcessingMeetings =>
      meetings.any((meeting) => meeting.isProcessing);

  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;

  bool get hasListRefreshError => listRefreshError != null;

  bool get hasDetailsRefreshError => detailsRefreshError != null;

  bool get isEmpty =>
      listStatus == MeetingRequestStatus.success && meetings.isEmpty;

  bool get canUseSelectedMeeting =>
      selectedMeeting != null &&
      detailsStatus == MeetingRequestStatus.success &&
      !isRefreshingDetails &&
      !hasDetailsRefreshError &&
      !isMutating;

  MeetingNotesState copyWith({
    List<KnowledgeSourceSummary>? meetings,
    List<MeetingClientModel>? clients,
    KnowledgeSourceDetails? selectedMeeting,
    MeetingRequestStatus? listStatus,
    MeetingRequestStatus? clientsStatus,
    MeetingRequestStatus? detailsStatus,
    MeetingRequestStatus? createStatus,
    MeetingRequestStatus? deleteStatus,
    MeetingRequestStatus? retryStatus,
    bool? isRefreshing,
    bool? isRefreshingDetails,
    String? deletingId,
    String? errorMessage,
    String? listRefreshError,
    String? detailsRefreshError,
    bool clearSelectedMeeting = false,
    bool clearDeletingId = false,
    bool clearError = false,
    bool clearListRefreshError = false,
    bool clearDetailsRefreshError = false,
  }) {
    return MeetingNotesState(
      meetings: meetings ?? this.meetings,
      clients: clients ?? this.clients,
      selectedMeeting: clearSelectedMeeting
          ? null
          : selectedMeeting ?? this.selectedMeeting,
      listStatus: listStatus ?? this.listStatus,
      clientsStatus: clientsStatus ?? this.clientsStatus,
      detailsStatus: detailsStatus ?? this.detailsStatus,
      createStatus: createStatus ?? this.createStatus,
      deleteStatus: deleteStatus ?? this.deleteStatus,
      retryStatus: retryStatus ?? this.retryStatus,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isRefreshingDetails: isRefreshingDetails ?? this.isRefreshingDetails,
      deletingId: clearDeletingId ? null : deletingId ?? this.deletingId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      listRefreshError: clearListRefreshError
          ? null
          : listRefreshError ?? this.listRefreshError,
      detailsRefreshError: clearDetailsRefreshError
          ? null
          : detailsRefreshError ?? this.detailsRefreshError,
    );
  }

  @override
  List<Object?> get props => [
    meetings,
    clients,
    selectedMeeting,
    listStatus,
    clientsStatus,
    detailsStatus,
    createStatus,
    deleteStatus,
    retryStatus,
    isRefreshing,
    isRefreshingDetails,
    deletingId,
    errorMessage,
    listRefreshError,
    detailsRefreshError,
  ];
}
