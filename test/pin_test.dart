import 'package:flutter_test/flutter_test.dart';
import 'package:whisper/logic/pin.dart';

void main() {
  final a = 'aa' * 32, b = 'bb' * 32;

  test('latest wins; same second settles the same way on both sides', () {
    expect(Pin.newer(null, Pin(a, 1)), isTrue);
    expect(Pin.newer(Pin(a, 1), Pin(b, 2)), isTrue);
    expect(Pin.newer(Pin(b, 2), Pin(a, 1)), isFalse);
    expect(Pin.newer(Pin(a, 5), Pin(b, 5)), isTrue);
    expect(Pin.newer(Pin(b, 5), Pin(a, 5)), isFalse);
    expect(Pin.newer(Pin(a, 5), Pin(a, 5)), isFalse, reason: 'replay');
    expect(Pin.newer(Pin(a, 5), Pin(null, 6)), isTrue, reason: 'unpin');
  });

  test('rumor round-trip, unpin, junk', () {
    final r = Pin.rumor(sender: b, to: [a], messageId: a, createdAt: 9);
    final p = Pin.fromRumor(r)!;
    expect((p.messageId, p.at), (a, 9));
    final unpin = Pin.rumor(sender: b, to: [a], messageId: null);
    expect(Pin.fromRumor(unpin)!.messageId, isNull);
    final junk = Pin.rumor(sender: b, to: [a], messageId: 'nope');
    expect(Pin.fromRumor(junk), isNull);
    expect(Pin.fromJson(Pin(a, 3).toJson())!.messageId, a);
    expect(Pin.fromJson({'at': 'x'}), isNull);
  });
}
