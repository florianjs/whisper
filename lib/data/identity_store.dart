import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../logic/identity.dart';
import 'key_vault.dart';

/// Owns the user's identity. Only the derived keys are kept, in the
/// [KeyVault]; the recovery phrase is shown once at creation and never
/// stored — the user's own backup is its only copy. Nothing here touches the
/// network.
class IdentityStore extends ChangeNotifier {
  /// [derive] defaults to a background isolate: PBKDF2 + BIP32 take ~1s in
  /// pure Dart. Tests inject a synchronous one (isolates don't run under
  /// fake async).
  IdentityStore(
    this._vault, {
    Future<Identity> Function(String mnemonic)? derive,
  }) : _derive = derive ?? ((m) => compute(deriveIdentity, m));

  static const _vaultKey = 'identity';

  final KeyVault _vault;
  final Future<Identity> Function(String mnemonic) _derive;

  Identity? _identity;
  Identity? get identity => _identity;
  bool get hasIdentity => _identity != null;

  String? _draftMnemonic;
  Identity? _draftIdentity;

  /// Mnemonic generated during onboarding, not persisted until
  /// [confirmDraft] — so abandoning the flow leaves no half-created account.
  String? get draftMnemonic => _draftMnemonic;
  Identity? get draftIdentity => _draftIdentity;

  Future<void> hydrate() async {
    final raw = await _vault.read(_vaultKey);
    if (raw == null) return;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final identity = Identity(
      privateKey: json['privateKey'] as String,
      publicKey: json['publicKey'] as String,
    );
    // Earlier versions also stored the phrase: rewrite the entry without it.
    if (json.containsKey('mnemonic')) await _persist(identity);
    _identity = identity;
    notifyListeners();
  }

  int _creation = 0;

  Future<void> startCreation() async {
    final token = ++_creation;
    final mnemonic = generateMnemonic();
    final derived = await _derive(mnemonic);
    // The user backed out (or restarted) while keys were being derived.
    if (token != _creation) return;
    _draftMnemonic = mnemonic;
    _draftIdentity = derived;
    notifyListeners();
  }

  void discardDraft() {
    _creation++;
    _draftMnemonic = null;
    _draftIdentity = null;
    notifyListeners();
  }

  Future<void> confirmDraft() async {
    final mnemonic = _draftMnemonic;
    final derived = _draftIdentity;
    if (mnemonic == null || derived == null) {
      throw StateError('no draft to confirm');
    }
    await _persist(derived);
    _draftMnemonic = null;
    _draftIdentity = null;
    notifyListeners();
  }

  /// Throws [ArgumentError] if [mnemonic] is not a valid BIP39 phrase.
  Future<void> restore(String mnemonic) async {
    final normalized = normalizeMnemonic(mnemonic);
    if (!isValidMnemonic(normalized)) throw ArgumentError('invalid mnemonic');
    final derived = await _derive(normalized);
    await _persist(derived);
    notifyListeners();
  }

  /// App lock: drop the identity from memory only. Listeners clear their
  /// in-memory state exactly as after a wipe, but nothing is deleted.
  void forget() {
    if (_identity == null) return;
    _identity = null;
    discardDraft();
  }

  /// Logs out even if the vault delete throws: the panic button must never
  /// leave the user signed in.
  Future<void> wipe() async {
    try {
      await _vault.delete(_vaultKey);
    } finally {
      _identity = null;
      discardDraft();
    }
  }

  Future<void> _persist(Identity derived) async {
    await _vault.write(
      _vaultKey,
      jsonEncode({
        'privateKey': derived.privateKey,
        'publicKey': derived.publicKey,
      }),
    );
    _identity = derived;
  }
}
