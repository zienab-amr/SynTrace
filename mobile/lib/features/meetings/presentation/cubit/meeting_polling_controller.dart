import 'dart:async';

/// Owns the timer only. Request guards and state remain in the cubit.
class MeetingPollingController {
  Timer? _timer;
  static const _interval = Duration(seconds: 10);

  void start(Future<void> Function() onTick) {
    if (_timer?.isActive ?? false) return;
    _timer = Timer.periodic(_interval, (_) => unawaited(onTick()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
