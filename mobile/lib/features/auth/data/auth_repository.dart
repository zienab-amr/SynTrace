import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/network/api_response.dart';
import 'package:syntrace/features/auth/data/models/auth_models.dart';

/// ═══════════════════════════════════════════════════════════
/// AuthRepository
/// 
/// الوسيط بين الـ Cubit والـ API
/// حالياً: Mock Data
/// بعدين: API حقيقي (بس نغيّر الـ Implementation)
/// ═══════════════════════════════════════════════════════════
class AuthRepository {
  // ═══════════════════════════════════════════════════════
  // Login
  // ═══════════════════════════════════════════════════════
  Future<ApiResponse<AuthResponse>> login(LoginRequest request) async {
    // ─── محاكاة تأخير الشبكة ───
    await Future.delayed(const Duration(milliseconds: 800));

    // ─── Validation بسيطة ───
    if (request.email.isEmpty || request.password.isEmpty) {
      return ApiResponse.failure(
        message: 'Email and password are required',
      );
    }

    if (request.password.length < 6) {
      return ApiResponse.failure(
        message: 'Password must be at least 6 characters',
      );
    }

    // ─── نجاح (Mock) ───
    return ApiResponse.success(
      data: _buildMockResponse(
        email: request.email,
        name: _nameFromEmail(request.email),
      ),
      message: 'Login successful',
    );

    // ═══════════════════════════════════════════════════════
    // لما نربط بالـ Backend، بنستبدل الكود ده بـ:
    // ═══════════════════════════════════════════════════════
    // return ApiClient.instance.safeRequest<AuthResponse>(
    //   request: () => ApiClient.instance.post(
    //     ApiEndpoints.login,
    //     data: request.toJson(),
    //   ),
    //   fromData: (data) => AuthResponse.fromJson(data as Map<String, dynamic>),
    // );
  }

  // ═══════════════════════════════════════════════════════
  // Signup
  // ═══════════════════════════════════════════════════════
  Future<ApiResponse<AuthResponse>> signup(SignupRequest request) async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (request.fullName.isEmpty ||
        request.email.isEmpty ||
        request.password.isEmpty) {
      return ApiResponse.failure(
        message: 'All fields are required',
      );
    }

    if (request.password.length < 6) {
      return ApiResponse.failure(
        message: 'Password must be at least 6 characters',
      );
    }

    return ApiResponse.success(
      data: _buildMockResponse(
        email: request.email,
        name: request.fullName,
      ),
      message: 'Account created successfully',
    );
  }

  // ═══════════════════════════════════════════════════════
  // Logout
  // ═══════════════════════════════════════════════════════
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
    // TODO: Call logout API + clear storage
  }

  // ═══════════════════════════════════════════════════════
  // Helpers (Mock)
  // ═══════════════════════════════════════════════════════
  AuthResponse _buildMockResponse({
    required String email,
    required String name,
  }) {
    return AuthResponse(
      token: 'mock_jwt_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'mock_refresh_${DateTime.now().millisecondsSinceEpoch}',
      user: UserModel(
        id: 'user-${email.hashCode}',
        name: name,
        email: email,
        role: UserRole.manager,
        tenantId: 'tenant-A',
        createdAt: DateTime.now(),
      ),
    );
  }

  String _nameFromEmail(String email) {
    if (email.isEmpty) return 'User';
    final prefix = email.split('@').first;
    return prefix
        .split(RegExp(r'[._-]'))
        .map((part) => part.isNotEmpty
            ? '${part[0].toUpperCase()}${part.substring(1)}'
            : '')
        .join(' ');
  }
}