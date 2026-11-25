import 'package:syntrace/core/network/api_endpoints.dart';

class SignalRConfig {
  SignalRConfig._();

  static const String projectStatusPath = '/hubs/project-status';

  static String get projectStatusUrl =>
      Uri.parse(ApiEndpoints.baseUrl).resolve(projectStatusPath).toString();

  static const List<int> reconnectDelays = [0, 2000, 5000, 10000, 30000];
}
