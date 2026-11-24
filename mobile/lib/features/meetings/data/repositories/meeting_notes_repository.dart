import 'package:dio/dio.dart';
import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/network/api_endpoints.dart';

import '../models/knowledge_source_model.dart';
import '../models/meeting_client_model.dart';

class MeetingNotesRepository {
  final ApiClient _api;

  MeetingNotesRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  // ═══════════════════════════════════════════
  // Get Clients
  // ═══════════════════════════════════════════

  Future<List<MeetingClientModel>> getClients() async {
    final response = await _api.get(ApiEndpoints.clients);

    _ensureSuccess(response);

    final data = response.data as List;

    return data
        .map(
          (item) => MeetingClientModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  // ═══════════════════════════════════════════
  // Get Knowledge Sources
  // ═══════════════════════════════════════════

  Future<List<KnowledgeSourceSummary>> getSources({
    String? clientId,
    String? projectId,
    int skip = 0,
    int take = 100,
  }) async {
    final response = await _api.get(
      ApiEndpoints.knowledgeSources,
      queryParameters: {
        if (clientId != null) 'clientId': clientId,
        if (projectId != null) 'projectId': projectId,
        'skip': skip,
        'take': take,
      },
    );

    _ensureSuccess(response);

    final data = response.data as List;

    return data
        .map(
          (item) => KnowledgeSourceSummary.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  // ═══════════════════════════════════════════
  // Get Meeting Notes Only
  // ═══════════════════════════════════════════

  Future<List<KnowledgeSourceSummary>> getMeetings({
    String? clientId,
    String? projectId,
  }) async {
    final meetings = <KnowledgeSourceSummary>[];
    const pageSize = 100;
    var skip = 0;

    while (true) {
      final sources = await getSources(
        clientId: clientId,
        projectId: projectId,
        skip: skip,
        take: pageSize,
      );

      meetings.addAll(sources.where((source) => source.isMeeting));

      if (sources.length < pageSize) break;

      skip += sources.length;
    }

    return meetings;
  }

  // ═══════════════════════════════════════════
  // Create Meeting
  // ═══════════════════════════════════════════

  Future<KnowledgeSourceSummary> createMeeting(
    CreateKnowledgeSourceRequest request,
  ) async {
    final response = await _api.post(
      ApiEndpoints.knowledgeSources,
      data: request.toJson(),
    );

    _ensureSuccess(response);

    return KnowledgeSourceSummary.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  // ═══════════════════════════════════════════
  // Get Source Details
  // ═══════════════════════════════════════════

  Future<KnowledgeSourceDetails> getSourceDetails(
    String id, {
    int? version,
  }) async {
    final response = await _api.get(
      ApiEndpoints.knowledgeSourceById(id),
      queryParameters: {if (version != null) 'version': version},
    );

    _ensureSuccess(response);

    return KnowledgeSourceDetails.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  // ═══════════════════════════════════════════
  // Refresh Processing Status
  // ═══════════════════════════════════════════

  Future<KnowledgeSourceDetails> refreshStatus(String id) {
    return getSourceDetails(id);
  }

  // ═══════════════════════════════════════════
  // Retry Failed Extraction
  // ═══════════════════════════════════════════

  Future<void> retryExtraction({
    required String id,
    required int version,
  }) async {
    final response = await _api.post(
      ApiEndpoints.knowledgeSourceRetry(id, version),
    );

    _ensureSuccess(response);
  }

  // ═══════════════════════════════════════════
  // Delete Knowledge Source
  // ═══════════════════════════════════════════

  Future<void> deleteSource(String id) async {
    final response = await _api.delete(ApiEndpoints.knowledgeSourceById(id));

    _ensureSuccess(response);
  }

  // ═══════════════════════════════════════════
  // Response Validation
  // ═══════════════════════════════════════════

  void _ensureSuccess(Response response) {
    final statusCode = response.statusCode;

    if (statusCode != null && statusCode >= 200 && statusCode < 300) {
      return;
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Request failed ($statusCode)',
    );
  }

  // ═══════════════════════════════════════════
  // Error Message
  // ═══════════════════════════════════════════

  static String getErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;

      if (data is Map) {
        final detail = data['detail'];
        final message = data['message'];
        final title = data['title'];

        if (detail is String && detail.isNotEmpty) {
          return detail;
        }

        if (message is String && message.isNotEmpty) {
          return message;
        }

        if (title is String && title.isNotEmpty) {
          return title;
        }
      }

      switch (error.response?.statusCode) {
        case 400:
          return 'Invalid meeting information.';
        case 401:
          return 'Your session has expired.';
        case 403:
          return 'You do not have permission.';
        case 404:
          return 'Knowledge source not found.';
        case 409:
          return 'The source has changed. Please refresh.';
        case 429:
          return 'Too many requests. Try again later.';
        case 500:
        case 502:
        case 503:
          return 'Server unavailable. Try again later.';
      }

      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Connection timed out.';

        case DioExceptionType.connectionError:
          return 'Unable to connect to the server.';

        case DioExceptionType.cancel:
          return 'Request cancelled.';

        default:
          return error.message ?? 'Something went wrong.';
      }
    }

    if (error is FormatException || error is TypeError) {
      return 'Unexpected server response.';
    }

    return 'Something went wrong. Please try again.';
  }
}
