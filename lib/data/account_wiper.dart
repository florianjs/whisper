import 'dart:async';

import 'db.dart';
import 'identity_store.dart';
import 'key_vault.dart';
import 'lockable_vault.dart';
import 'tor_service.dart';

/// Panic button backend: erases everything this phone knows about the account.
///
/// Order matters. Keys go first — deleting the DB key makes the database
/// unreadable immediately (crypto-shredding), which holds even if the file
/// deletion below is interrupted or flash storage keeps remnants. Every step
/// runs even if an earlier one throws.
class AccountWiper {
  AccountWiper({
    required KeyVault vault,
    required DocStore db,
    required IdentityStore identity,
    required Future<void> Function() clearClipboard,
    Future<void> Function()? requestVanish,
    Future<void> Function()? clearNetworkState,
    this.vanishTimeout = const Duration(seconds: 3),
  }) : _vault = vault,
       _db = db,
       _identity = identity,
       _clearClipboard = clearClipboard,
       _requestVanish = requestVanish,
       _clearNetworkState = clearNetworkState;

  final KeyVault _vault;
  final DocStore _db;
  final IdentityStore _identity;
  final Future<void> Function() _clearClipboard;

  /// NIP-62 "request to vanish" to our relays: they delete our events and
  /// the gift wraps addressed to us. Needs the identity, so it runs before
  /// the identity is wiped — right after the DB key, bounded by
  /// [vanishTimeout] so an offline phone isn't held up.
  final Future<void> Function()? _requestVanish;
  final Duration vanishTimeout;

  /// Tor state/cache and pluggable-transport files (guard choices, bridge
  /// in use): not the account, but traces of the phone's network history.
  final Future<void> Function()? _clearNetworkState;

  /// Returns the errors of steps that failed (empty on full success).
  Future<List<Object>> panic() async {
    final errors = <Object>[];
    Future<void> step(Future<void> Function() run) async {
      try {
        await run();
      } catch (e) {
        errors.add(e);
      }
    }

    await step(() => _vault.delete(Db.keyName));
    final vanish = _requestVanish;
    if (vanish != null) await step(() => vanish().timeout(vanishTimeout));
    // Deletes the identity from the vault and always resets in-memory state,
    // which sends the router back to the welcome screen.
    await step(_identity.wipe);
    await step(_db.destroy);
    await step(_clearClipboard);
    // "Tor off", "disguised", the rung that worked: all hint at past
    // choices or at the network the phone was on. Back to the defaults.
    for (final key in TorService.vaultKeys) {
      await step(() => _vault.delete(key));
    }
    await step(() => _vault.delete(Db.rawFlagName));
    final network = _clearNetworkState;
    if (network != null) await step(network);
    // App-lock artefacts (sealed blob, duress verifier, biometric slot).
    final vault = _vault;
    if (vault is LockableVault) await step(vault.deleteAll);
    return errors;
  }
}
