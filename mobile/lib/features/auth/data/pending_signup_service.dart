import 'package:syntrace/features/auth/data/models/auth_models.dart';

class PendingSignupService {
  PendingSignupService._();
  static final PendingSignupService instance = PendingSignupService._();

  SignupRequest? _pendingRequest;

  SignupRequest? get pendingRequest => _pendingRequest;

  DateTime? resendAt;
  DateTime? expiresAt;

  void markSent() {
    final now = DateTime.now();
    resendAt = now.add(const Duration(seconds: 60));
    expiresAt = now.add(const Duration(minutes: 5));
  }

  void save(SignupRequest request) {
    _pendingRequest = request;
    resendAt = null;
    expiresAt = null;
  }

  void clear() {
    _pendingRequest = null;
    resendAt = null;
    expiresAt = null;
  }
}
