import '../../data/models/project_client_model.dart';

class ClientsState {
  final List<ProjectClientModel>? clients;
  final bool loading;
  final bool cached;
  final String? error;
  final DateTime? expiresAt;
  bool get canMutate =>
      clients != null &&
      !loading &&
      !cached &&
      error == null &&
      expiresAt != null &&
      DateTime.now().toUtc().isBefore(expiresAt!);
  const ClientsState({
    this.clients,
    this.loading = false,
    this.cached = true,
    this.error,
    this.expiresAt,
  });
}
