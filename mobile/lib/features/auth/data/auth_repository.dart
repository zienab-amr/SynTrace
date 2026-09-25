import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/network/api_endpoints.dart';
import 'package:syntrace/core/network/api_response.dart';
import 'package:syntrace/features/auth/data/models/auth_models.dart';

/// ═══════════════════════════════════════════════════════════
/// AuthRepository
/// ═══════════════════════════════════════════════════════════
class AuthRepository {
  // ═══════════════════════════════════════════════════════
  // Login
  // ═══════════════════════════════════════════════════════
  Future<ApiResponse<AuthResponse>> login(LoginRequest request) async {
    return ApiClient.instance.safeRequest<AuthResponse>(
      // ─── الـ Request ───
      request: () => ApiClient.instance.post(
        ApiEndpoints.login,
        data: request.toJson(),
      ),
      // ─── Response ───
      fromData: (data) => AuthResponse.fromJson(data as Map<String, dynamic>),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Signup
  // ═══════════════════════════════════════════════════════
  Future<ApiResponse<AuthResponse>> signup(SignupRequest request) async {
    return ApiClient.instance.safeRequest<AuthResponse>(
      request: () => ApiClient.instance.post(
        ApiEndpoints.register,
        data: request.toJson(),
      ),
      fromData: (data) => AuthResponse.fromJson(data as Map<String, dynamic>),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Logout
  // ═══════════════════════════════════════════════════════
  Future<void> logout() async {
    try {
      await ApiClient.instance.post(ApiEndpoints.logout);
    } catch (_) {
    }
  }
}