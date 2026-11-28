import 'package:url_launcher/url_launcher.dart';

class SecureSourceLink {
  SecureSourceLink._();

  static Uri? parseHttps(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(value.trim());

    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.port != 443) {
      return null;
    }

    return uri;
  }

  static Uri? githubUri(String? value) {
    final uri = parseHttps(value);

    if (uri == null || uri.host.toLowerCase() != 'github.com') {
      return null;
    }

    return uri;
  }

  static Uri? jiraUri(String? value) {
    final uri = parseHttps(value);

    if (uri == null) return null;

    final host = uri.host.toLowerCase();

    if (!host.endsWith('.atlassian.net')) {
      return null;
    }

    if (!uri.path.startsWith('/browse/')) {
      return null;
    }

    return uri;
  }

  static Future<bool> openGitHub(String? value) {
    return _open(githubUri(value));
  }

  static Future<bool> openJira(String? value) {
    return _open(jiraUri(value));
  }

  static Future<bool> _open(Uri? uri) async {
    if (uri == null) return false;

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
