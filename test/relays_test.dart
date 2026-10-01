import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:whisper/logic/relays.dart';

void main() {
  group('healthOf', () {
    test('online as soon as one relay is up', () {
      expect(
        healthOf({'a': false, 'b': true}, settled: false),
        RelayHealth.online,
      );
    });

    test('connecting until the first attempt settles, then offline', () {
      final down = {'a': false, 'b': false};
      expect(healthOf(down, settled: false), RelayHealth.connecting);
      expect(healthOf(down, settled: true), RelayHealth.offline);
      expect(healthOf({}, settled: true), RelayHealth.offline);
    });
  });

  group('retryDelay', () {
    test('grows exponentially and caps at 60s (±20%)', () {
      final rng = Random(1);
      for (final (attempt, base) in [
        (0, 2),
        (1, 4),
        (2, 8),
        (4, 32),
        (9, 60),
      ]) {
        final d = retryDelay(attempt, random: rng).inMilliseconds;
        expect(
          d,
          inInclusiveRange(base * 800, base * 1200),
          reason: '$attempt',
        );
      }
    });
  });

  group('normalizeRelayUrl', () {
    test('canonicalizes', () {
      expect(
        normalizeRelayUrl(' WSS://Relay.Damus.IO/ '),
        'wss://relay.damus.io',
      );
      expect(
        normalizeRelayUrl('wss://r.example:4443/inbox'),
        'wss://r.example:4443/inbox',
      );
    });

    test('rejects insecure or malformed URLs', () {
      expect(normalizeRelayUrl('ws://relay.damus.io'), isNull);
      expect(
        normalizeRelayUrl('ws://ABCdef.onion/'),
        'ws://abcdef.onion',
        reason: 'ws:// is fine for onion services only',
      );
      expect(isOnionRelay('ws://abcdef.onion'), isTrue);
      expect(isOnionRelay('wss://nos.lol'), isFalse);
      expect(relayLabel('wss://nos.lol'), 'nos.lol');
      expect(relayLabel('ws://${'a' * 56}.onion'), 'aaaaaaaa….onion');
      expect(normalizeRelayUrl('https://relay.damus.io'), isNull);
      expect(normalizeRelayUrl('relay.damus.io'), isNull);
      expect(normalizeRelayUrl('wss://'), isNull);
    });

    test('defaults are all valid and canonical', () {
      for (final url in defaultRelays) {
        expect(normalizeRelayUrl(url), url);
      }
    });
  });

  group('accrueDowntime', () {
    const tick = Duration(minutes: 10);

    test('counts down relays while another one is up', () {
      final d = accrueDowntime({}, {'a': true, 'b': false, 'c': false}, tick);
      expect(d, {'b': tick, 'c': tick});
      expect(accrueDowntime(d, {'a': true, 'b': false, 'c': false}, tick), {
        'b': tick * 2,
        'c': tick * 2,
      });
    });

    test('a relay that connects starts over', () {
      final d = accrueDowntime({'b': tick * 5}, {'a': true, 'b': true}, tick);
      expect(d, isEmpty);
    });

    test('all down = we are offline: nothing changes', () {
      final before = {'b': tick};
      expect(accrueDowntime(before, {'a': false, 'b': false}, tick), before);
    });
  });

  group('failover', () {
    test('nothing dead, nothing to do', () {
      expect(
        failover(
          relays: ['a', 'b'],
          spares: ['s1'],
          downtime: {'b': const Duration(hours: 5)},
        ),
        isNull,
      );
    });

    test('dead relay replaced in place, sent to the back of the spares', () {
      final r = failover(
        relays: ['a', 'b', 'c'],
        spares: ['s1', 's2'],
        downtime: {'b': deadRelayAfter},
      )!;
      expect(r.relays, ['a', 's1', 'c']);
      expect(r.spares, ['s2', 'b']);
    });

    test('skips spares already in the list; stops when none is left', () {
      final r = failover(
        relays: ['a', 'b', 's1'],
        spares: ['s1', 's2'],
        downtime: {'a': deadRelayAfter, 'b': deadRelayAfter},
      )!;
      expect(r.relays, ['s2', 'b', 's1']);
      expect(r.spares, ['a']);
    });

    test('no spare left: null', () {
      expect(
        failover(
          relays: ['a', 's1'],
          spares: ['s1'],
          downtime: {'a': deadRelayAfter},
        ),
        isNull,
      );
    });

    test('spares are distinct from the main list', () {
      expect(spareRelays.toSet().intersection(defaultRelays.toSet()), isEmpty);
      expect(spareRelays.map(normalizeRelayUrl), spareRelays);
    });
  });
}
