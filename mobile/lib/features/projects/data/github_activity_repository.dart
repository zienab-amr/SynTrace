import 'package:dio/dio.dart';

import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/network/api_endpoints.dart';

import 'models/github_activity_model.dart';

class GitHubActivityRepository {
  final ApiClient _api;

  GitHubActivityRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  Future<GitHubActivityPage> getActivity({
    required String projectId,
    required GitHubActivityKind kind,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    if (projectId.trim().isEmpty) {
      throw ArgumentError('Project ID is required.');
    }

    if (offset < 0) {
      throw ArgumentError('Invalid activity offset.');
    }

    final response = await _api.get(
      ApiEndpoints.githubProjectActivity(projectId),
      queryParameters: {'kind': kind.apiValue, 'offset': offset},
      cancelToken: cancelToken,
    );

    final statusCode = response.statusCode;

    if (statusCode == null || statusCode < 200 || statusCode >= 300) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }

    final data = response.data;

    if (data is! Map) {
      throw const FormatException('Invalid GitHub activity response.');
    }

    final page = GitHubActivityPage.fromJson(
      Map<String, dynamic>.from(data),
      kind,
    );

    if (page.nextOffset != null && page.nextOffset! <= offset) {
      throw const FormatException('Invalid pagination offset.');
    }

    return page;
  }
}
