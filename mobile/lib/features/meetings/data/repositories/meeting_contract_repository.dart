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
