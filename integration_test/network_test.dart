import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whisper/data/db.dart';
import 'package:whisper/data/identity_store.dart';
import 'package:whisper/data/key_vault.dart';
import 'package:whisper/data/relay_service.dart';
import 'package:whisper/data/tor_service.dart';
import 'package:whisper/logic/identity.dart';
import 'package:whisper/logic/tor_proxy.dart';

/// Runs on a real device / simulator, with the real network: Tor
/// bootstraps, then relays connect through it. Unit tests fake both, which
/// is how a release with no network permission slipped through once.
///
///   fvm flutter test integration_test -d DEVICE_ID
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Tor bootstraps and relays connect through it',
    (tester) async {
      final tor = TorService(MemoryKeyVault());
      HttpOverrides.global = TorHttpOverrides(
        () => (wanted: tor.wanted, proxy: tor.proxy),
      );
      await tor.init();
      await _until(
        () => tor.state == TorState.ready,
        const Duration(minutes: 3),
      );

      final identity = IdentityStore(
        MemoryKeyVault(),
        derive: (m) async => deriveIdentity(m),
      );
      final relays = RelayService(identity: identity, db: MemoryDocStore());
      // Public test vector: a throwaway account, never used for real.
      await identity.restore(
        'leader monkey parrot ring guide accident before fence cannon height naive bean',
      );
      await _until(() => relays.connectedCount > 0, const Duration(minutes: 2));
      expect(relays.connectedCount, greaterThan(0));
      relays.dispose();
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

Future<void> _until(bool Function() done, Duration timeout) async {
  final end = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(end)) throw TimeoutException('not reached');
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
}
