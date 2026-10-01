import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/lockable_vault.dart';
import '../data/settings_store.dart';
import '../l10n/app_localizations.dart';
import '../logic/pin_crypto.dart';
import '../logic/secure_platform.dart';
import '../widgets/pin_pad.dart';

enum PinSetupMode { enable, change, duress, disable }

/// Two-step "choose + confirm" (or one-step "current PIN" for disable).
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key, required this.mode});

  final PinSetupMode mode;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String? _first;

  @override
  void initState() {
    super.initState();
    SecurePlatform.acquireSecureScreen();
  }

  @override
  void dispose() {
    SecurePlatform.releaseSecureScreen();
    super.dispose();
  }

  Future<String?> _submit(String pin) async {
    final l = AppLocalizations.of(context);
    final vault = context.read<LockableVault>();
    final navigator = Navigator.of(context);

    if (widget.mode == PinSetupMode.disable) {
      // Re-check the PIN before removing the protection.
      final r = await vault.verifyPin(pin);
      if (r.outcome != UnlockOutcome.ok) {
        return r.retryAfter > Duration.zero
            ? l.lockRetryIn(r.retryAfter.inSeconds)
            : l.lockWrongPin;
      }
      await vault.disable();
      navigator.pop();
      return null;
    }

    if (_first == null) {
      if (!isAcceptablePin(pin)) return l.pinWeak;
      setState(() => _first = pin);
      return null;
    }
    if (pin != _first) {
      setState(() => _first = null);
      return l.pinMismatch;
    }
    try {
      switch (widget.mode) {
        case PinSetupMode.enable:
          await vault.enable(pin);
        case PinSetupMode.change:
          await vault.changePin(pin);
        case PinSetupMode.duress:
          await vault.setDuressPin(pin);
        case PinSetupMode.disable:
          break;
      }
    } on ArgumentError {
      setState(() => _first = null);
      return widget.mode == PinSetupMode.duress ? l.pinSameAsReal : l.pinWeak;
    }
    navigator.pop();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final shuffle = context.watch<SettingsStore>().paranoia.shuffleKeys;
    final title = switch ((widget.mode, _first == null)) {
      (PinSetupMode.disable, _) => l.pinCurrentTitle,
      (PinSetupMode.duress, true) => l.pinDuressTitle,
      (_, true) => l.pinNewTitle,
      (_, false) => l.pinConfirmTitle,
    };
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            child: PinEntry(
              // New key per step so the dots reset between choose/confirm.
              key: ValueKey(_first == null),
              title: title,
              subtitle: widget.mode == PinSetupMode.disable ? null : l.pinRules,
              shuffle: shuffle,
              busyLabel: l.pinEncrypting,
              onSubmit: _submit,
            ),
          ),
        ),
      ),
    );
  }
}
