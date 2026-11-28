import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:syntrace/core/network/api_client.dart';

class MeetingContractRepository {
  MeetingContractRepository({ApiClient? api})
    : _api = api ?? ApiClient.instance;

  static const enabled = bool.fromEnvironment('ENABLE_MEETING_CONTRACT');
  static const _path = '/meetings';
  final ApiClient _api;

  String _meetingPath(String id) => '$_path/${Uri.encodeComponent(id)}';

  Future<Map<String, dynamic>> create({
    required String projectId,
    required String sourceType,
    required String title,
    required DateTime date,
    String? text,
    String? pdfBase64,
    List<String> glossary = const [],
    String? linkedSourceId,
  }) async => _body(
    await _api.post(
      _path,
      data: {
        'projectKey': projectId,
        'sourceType': sourceType,
        'title': title,
        'meetingDate': date.toIso8601String().split('T').first,
        'text': ?text,
        'pdfBase64': ?pdfBase64,
        'glossary': glossary,
        'linkedSourceId': ?linkedSourceId,
      },
    ),
  );

  Future<Map<String, dynamic>> get(String id) async =>
      _body(await _api.get(_meetingPath(id)));

  Future<Map<String, dynamic>> review(
    String id, {
    required List<String> approve,
    required List<String> delete,
    required Map<String, List<String>> links,
  }) async => _body(
    await _api.post(
      '${_meetingPath(id)}/review',
      data: {'approve': approve, 'delete': delete, 'links': links},
    ),
  );

  Future<Map<String, dynamic>> document(String id) async =>
      _body(await _api.get('${_meetingPath(id)}/document'));

  Future<Map<String, dynamic>> saveDocument(String id, String text) async =>
      _body(
        await _api.put('${_meetingPath(id)}/document', data: {'text': text}),
      );

  Future<Map<String, dynamic>> rewrite(
    String id,
    String instruction, {
    String? part,
  }) async => _body(
    await _api.post(
      '${_meetingPath(id)}/document/rewrite',
      data: {'instruction': instruction, 'part': ?part},
    ),
  );

  Future<Uint8List> requirementsPdf(String id) async {
    final response = await _api.get(
      '${_meetingPath(id)}/requirements.pdf',
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Accept': 'application/pdf'},
      ),
    );
    _ensureSuccess(response);
    final contentType = response.headers
        .value('content-type')
        ?.split(';')
        .first;
    if (contentType != 'application/pdf' || response.data is! List<int>) {
      throw const FormatException('Invalid requirements PDF response.');
    }
    return Uint8List.fromList(response.data as List<int>);
  }

  /// Reads a failed meeting again from the text it was sent with.
  Future<Map<String, dynamic>> retry(String id) async =>
      _body(await _api.post('${_meetingPath(id)}/retry'));

  Future<void> delete(String id) async =>
      _ensureSuccess(await _api.delete(_meetingPath(id)));

  /// The project's meetings, newest first, without their text.
  Future<List<Map<String, dynamic>>> list(
    String projectKey, {
    String? status,
  }) async => _list(
    _body(
      await _api.get(
        _path,
        queryParameters: {'projectKey': projectKey, 'status': ?status},
      ),
    ),
    'meetings',
  );

  /// The project's requirements with their story across meetings.
  Future<List<Map<String, dynamic>>> requirements(
    String projectKey, {
    String? query,
  }) async => _list(
    _body(
      await _api.get(
        '$_path/projects/${Uri.encodeComponent(projectKey)}/requirements',
        queryParameters: {
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        },
      ),
    ),
    'requirements',
  );

  Future<List<Map<String, dynamic>>> editRequirement(
    String requirementId,
    String text,
  ) async => _list(
    _body(
      await _api.patch(
        '$_path/requirements/${Uri.encodeComponent(requirementId)}',
        data: {'text': text},
      ),
    ),
    'requirements',
  );

  /// Questions from approved meetings that no later meeting answered.
  Future<List<Map<String, dynamic>>> openQuestions(String projectKey) async =>
      _list(
        _body(
          await _api.get(
            '$_path/projects/${Uri.encodeComponent(projectKey)}/open-questions',
          ),
        ),
        'openQuestions',
      );

  String _livePath(String id) => '$_path/live/${Uri.encodeComponent(id)}';

  Future<Map<String, dynamic>> startLive(
    String projectKey, {
    String? title,
  }) async => _body(
    await _api.post(
      '$_path/live',
      data: {'projectKey': projectKey, 'title': ?title},
    ),
  );

  Future<Map<String, dynamic>> getLive(String sessionId) async =>
      _body(await _api.get(_livePath(sessionId)));

  /// Send the transcript so far (and a question): only help not given before comes back.
  Future<Map<String, dynamic>> assistLive(
    String sessionId, {
    required String transcript,
    String? question,
    List<String> dismiss = const [],
  }) async => _body(
    await _api.post(
      '${_livePath(sessionId)}/assist',
      data: {
        'transcript': transcript,
        'question': ?question,
        'dismiss': dismiss,
      },
    ),
  );

  Future<Map<String, dynamic>> wrapUpLive(
    String sessionId,
    String transcript,
  ) async => _body(
    await _api.post(
      '${_livePath(sessionId)}/wrap-up',
      data: {'transcript': transcript},
    ),
  );

  /// Ends the session; a transcript sent here goes to review as a meeting.
  Future<Map<String, dynamic>> endLive(
    String sessionId, {
    String? transcript,
    DateTime? date,
  }) async => _body(
    await _api.post(
      '${_livePath(sessionId)}/end',
      data: {
        'transcript': ?transcript,
        if (transcript != null && date != null)
          'meetingDate': date.toIso8601String().split('T').first,
      },
    ),
  );

  Future<void> deleteLive(String sessionId) async =>
      _ensureSuccess(await _api.delete(_livePath(sessionId)));

  /// Creates the Jira ticket of an approved draft: {jiraKey, url, subtaskKeys, failedSubtasks}.
  Future<Map<String, dynamic>> publishDraft(
    String meetingId,
    String draftId,
  ) async => _body(
    await _api.post(
      '${_meetingPath(meetingId)}/drafts/${Uri.encodeComponent(draftId)}/publish',
    ),
  );

  List<Map<String, dynamic>> _list(Map<String, dynamic> body, String field) =>
      [
        for (final row in body[field] as List? ?? const [])
          if (row is Map) Map<String, dynamic>.from(row),
      ];

  Future<Set<String>> permissions() async =>
      (_body(await _api.get('$_path/permissions'))['permissions'] as List)
          .cast<String>()
          .toSet();

  Map<String, dynamic> _body(Response response) {
    _ensureSuccess(response);
    return Map<String, dynamic>.from(response.data as Map);
  }

  void _ensureSuccess(Response response) {
    final status = response.statusCode;
    if (status == null || status < 200 || status >= 300) {
      throw DioException.badResponse(
        statusCode: status ?? 500,
        requestOptions: response.requestOptions,
        response: response,
      );
    }
  }
}
