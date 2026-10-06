import 'package:syntrace/features/auth/data/models/auth_models.dart';

class PendingSignupService {
  PendingSignupService._();
  static final PendingSignupService instance = PendingSignupService._();

  SignupRequest? _pendingRequest;

  SignupRequest? get pendingRequest => _pendingRequest;

  void save(SignupRequest request) => _pendingRequest = request;
  void clear() => _pendingRequest = null;
}