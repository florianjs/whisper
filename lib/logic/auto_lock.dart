/// Auto-lock bookkeeping. Leaving the app on purpose (photo picker, camera,
/// system settings) hides it too; those flows suspend auto-lock so the user
/// doesn't come back to a lock screen with their pick lost.
class AutoLock {
  AutoLock._();

  static int _suspended = 0;
  static bool get suspended => _suspended > 0;

  static Future<T> suspendWhile<T>(Future<T> Function() action) async {
    _suspended++;
    try {
      return await action();
    } finally {
      _suspended--;
    }
  }

  static bool shouldLock({
    required DateTime hiddenAt,
    required DateTime now,
    required Duration after,
  }) => now.difference(hiddenAt) >= after;
}
