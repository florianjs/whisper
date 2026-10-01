import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:whisper/data/notifier.dart';
import 'package:whisper/models/message.dart';

class FakeSink implements NotificationSink {
  final shown = <int>[];
  int clears = 0;
  @override
  Future<void> show(int count) async => shown.add(count);
  @override
  Future<void> clear() async => clears++;
}

Message msg(String id, {DateTime? at}) => Message(
  id: id,
  peer: 'ab' * 32,
  fromMe: false,
  text: 'secret text',
  createdAt: (at ?? DateTime(2026, 9, 30, 12)).millisecondsSinceEpoch ~/ 1000,
  status: MessageStatus.received,
);

void main() {
  late StreamController<Message> dms, groups;
  late FakeSink sink;
  late bool enabled;
  late ArrivalNotifier n;

  setUp(() {
    dms = StreamController<Message>(sync: true);
    groups = StreamController<Message>(sync: true);
    sink = FakeSink();
    enabled = true;
    n = ArrivalNotifier(
      arrivals: [dms.stream, groups.stream],
      sink: sink,
      enabled: () => enabled,
      now: () => DateTime(2026, 9, 30, 12, 5),
    );
  });

  test('foreground: never notifies', () {
    dms.add(msg('a'));
    expect(sink.shown, isEmpty);
  });

  test('background: counts DMs and group messages, once each', () {
    n.setForeground(false);
    dms.add(msg('a'));
    groups.add(msg('b'));
    dms.add(msg('a'));
    expect(sink.shown, [1, 2]);
  });

  test('back to foreground clears the notification and the count', () {
    n.setForeground(false);
    dms.add(msg('a'));
    n.setForeground(true);
    expect(sink.clears, 1);
    n.setForeground(false);
    dms.add(msg('b'));
    expect(sink.shown, [1, 1]);
  });

  test('history from a restore is not news; days-late delivery is', () {
    n.setForeground(false);
    dms.add(msg('old', at: DateTime(2026, 9, 1)));
    dms.add(msg('late', at: DateTime(2026, 9, 28)));
    expect(sink.shown, [1]);
  });

  test('disabled in settings: silent', () {
    enabled = false;
    n.setForeground(false);
    dms.add(msg('a'));
    expect(sink.shown, isEmpty);
  });

  test('reset clears everything (panic)', () async {
    n.setForeground(false);
    dms.add(msg('a'));
    await n.reset();
    expect(sink.clears, 1);
    expect(n.unread, 0);
  });
}
