import 'dart:async';

import '../models/message.dart';

/// Where "new message" notifications go (the platform in the app, a fake in
/// tests).
abstract class NotificationSink {
  /// Shows or updates the single notification for [count] unread messages.
  Future<void> show(int count);
  Future<void> clear();
}

/// Content-free notifications for messages arriving while the app is in the
/// background: a count, never a name or text — the lock screen and
/// notification history are readable by anyone holding the phone, and by
/// apps with notification access.
class ArrivalNotifier {
  ArrivalNotifier({
    required Iterable<Stream<Message>> arrivals,
    required NotificationSink sink,
    required bool Function() enabled,
    DateTime Function()? now,
  }) : _sink = sink,
       _enabled = enabled,
       _now = now ?? DateTime.now {
    for (final s in arrivals) {
      _subs.add(s.listen(_onArrival));
    }
  }

  final NotificationSink _sink;
  final bool Function() _enabled;
  final DateTime Function() _now;
  final _subs = <StreamSubscription<Message>>[];
  final _seen = <String>{};

  /// Stores only emit messages they didn't have, so replays are silent.
  /// What's left to filter is history pulled by a restore: anything older
  /// than this isn't news. (A message sent while the phone was offline for
  /// a few days still is.)
  static const historyAge = Duration(days: 7);
  bool _foreground = true;
  int _unread = 0;

  int get unread => _unread;

  void _onArrival(Message m) {
    if (_foreground || !_enabled()) return;
    if (m.time.isBefore(_now().subtract(historyAge))) return;
    if (!_seen.add(m.id)) return;
    _unread++;
    unawaited(_sink.show(_unread));
  }

  /// App visible again: the user sees the messages, drop the notification.
  void setForeground(bool foreground) {
    _foreground = foreground;
    if (foreground) {
      if (_unread > 0) {
        _unread = 0;
        unawaited(_sink.clear());
      }
      _seen.clear();
    }
  }

  /// Panic / sign-out: nothing may linger in the notification shade.
  Future<void> reset() async {
    _unread = 0;
    _seen.clear();
    await _sink.clear();
  }

  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
  }
}
