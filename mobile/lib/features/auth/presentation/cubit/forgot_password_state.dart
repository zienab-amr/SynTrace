class ForgotPasswordState {
  final String? email;
  final bool busy;
  final bool completed;
  final DateTime? resendAt;
  final String? message;

  const ForgotPasswordState({
    this.email,
    this.busy = false,
    this.completed = false,
    this.resendAt,
    this.message,
  });
}
