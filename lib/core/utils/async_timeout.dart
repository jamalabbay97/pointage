import 'dart:async';

/// Runs [action] and fails with [TimeoutException] after [duration].
Future<T> withTimeout<T>(
  Future<T> action, {
  required Duration duration,
  String? label,
}) {
  return action.timeout(
    duration,
    onTimeout: () {
      throw TimeoutException(
        label ?? 'Operation timed out after ${duration.inSeconds}s',
        duration,
      );
    },
  );
}
