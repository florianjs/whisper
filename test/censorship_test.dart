import 'package:flutter_test/flutter_test.dart';
import 'package:whisper/logic/censorship.dart';

void main() {
  test('fresh start climbs from plain Tor', () {
    expect(torLadder(), [TorLevel.tor, TorLevel.obfs4, TorLevel.snowflake]);
  });

  test('starts where it last worked, then tries skipped rungs', () {
    expect(torLadder(lastGood: TorLevel.snowflake), [
      TorLevel.snowflake,
      TorLevel.tor,
      TorLevel.obfs4,
    ]);
    expect(torLadder(lastGood: TorLevel.obfs4), [
      TorLevel.obfs4,
      TorLevel.snowflake,
      TorLevel.tor,
    ]);
  });

  test('disguise never tries plain Tor', () {
    expect(torLadder(disguise: true), [TorLevel.obfs4, TorLevel.snowflake]);
    expect(torLadder(lastGood: TorLevel.tor, disguise: true), [
      TorLevel.obfs4,
      TorLevel.snowflake,
    ]);
    expect(torLadder(lastGood: TorLevel.snowflake, disguise: true), [
      TorLevel.snowflake,
      TorLevel.obfs4,
    ]);
  });

  test('every disguised rung has bridges and a transport', () {
    for (final l in TorLevel.values.where((l) => l.disguised)) {
      expect(l.bridges, isNotEmpty);
      expect(l.transport, isNotNull);
      for (final b in l.bridges) {
        expect(b, startsWith('${l.transport} '));
      }
    }
    expect(TorLevel.tor.bridges, isEmpty);
    expect(TorLevel.tor.transport, isNull);
  });

  test('snowflake params come from the bridge line', () {
    final p = snowflakeParams(builtinSnowflake.first);
    expect(p['url'], 'https://1098762253.rsc.cdn77.org/');
    expect(p['fronts'], 'app.datapacket.com,www.datapacket.com');
    expect(p['ice'], startsWith('stun:'));
    expect(p.containsKey('fingerprint'), isFalse);
  });
}
