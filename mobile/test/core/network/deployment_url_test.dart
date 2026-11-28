import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/core/network/api_endpoints.dart';

void main() {
  final browser = Uri.parse('https://example.com/flutter/projects/123');

  test('root-relative API uses browser origin, not SPA subpath', () {
    final url = ApiEndpoints.resolveApiBaseUrl(
      '/api',
      isWeb: true,
      browserUri: browser,
    );
    expect(url, 'https://example.com/api');
    expect(ApiEndpoints.signalRBaseFor(url), 'https://example.com');
  });

  test('native API remains absolute and trailing slash is normalized', () {
    final url = ApiEndpoints.resolveApiBaseUrl(
      'https://api.example.com/api/',
      isWeb: false,
      browserUri: Uri.parse('file:///app/'),
    );
    expect(url, 'https://api.example.com/api');
    expect(ApiEndpoints.signalRBaseFor(url), 'https://api.example.com');
  });

  test('explicit absolute web API is supported', () {
    expect(
      ApiEndpoints.resolveApiBaseUrl(
        'https://api.example.com/api',
        isWeb: true,
        browserUri: browser,
      ),
      'https://api.example.com/api',
    );
  });

  test('explicit gateway prefix is preserved', () {
    final url = ApiEndpoints.resolveApiBaseUrl(
      '/gateway/api/',
      isWeb: true,
      browserUri: browser,
    );
    expect(url, 'https://example.com/gateway/api');
    expect(ApiEndpoints.signalRBaseFor(url), 'https://example.com/gateway');
  });

  test('reject native relative URLs and ambiguous web overrides', () {
    expect(
      () => ApiEndpoints.resolveApiBaseUrl(
        '/api',
        isWeb: false,
        browserUri: browser,
      ),
      throwsFormatException,
    );
    for (final value in [
      '//other.example/api',
      'api',
      'https://example.com/api?x=1',
      'https://example.com/api#x',
    ]) {
      expect(
        () => ApiEndpoints.resolveApiBaseUrl(
          value,
          isWeb: true,
          browserUri: browser,
        ),
        throwsFormatException,
      );
    }
  });
}
