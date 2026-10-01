import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/account_wiper.dart';
import '../data/lockable_vault.dart';
import '../data/settings_store.dart';
import '../l10n/app_localizations.dart';
import '../logic/secure_platform.dart';
import '../widgets/pin_pad.dart';
import '../widgets/ui.dart';

/// Shown whenever the vault is locked. Nothing from the account exists in
/// memory while it is up; unlocking re-hydrates everything.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _entry = GlobalKey<PinEntryState>();
  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    SecurePlatform.acquireSecureScreen();
    // Offer biometrics right away when set up.
    WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
  }

  @override
  void dispose() {
    _countdown?.cancel();
    SecurePlatform.releaseSecureScreen();
    super.dispose();
  }

  Future<void> _biometric() async {
    final vault = context.read<LockableVault>();
    if (!vault.biometricsEnabled || !vault.isLocked) return;
    final l = AppLocalizations.of(context);
    await vault.unlockWithBiometrics(
      title: l.lockBiometricPrompt,
      cancel: l.biometricCancel,
    );
  }

  Future<String?> _submit(String pin) async {
    final l = AppLocalizations.of(context);
    final vault = context.read<LockableVault>();
    final wiper = context.read<AccountWiper>();
    final result = await vault.unlock(pin);
    switch (result.outcome) {
      case UnlockOutcome.ok:
        return null;
      case UnlockOutcome.duress:
        // Silent: looks like a normal unlock into a fresh, empty app.
        await wiper.panic();
        return null;
      case UnlockOutcome.wrongPin:
      case UnlockOutcome.lockedOut:
        if (result.retryAfter > Duration.zero) {
          _startCountdown(result.retryAfter);
        }
        return result.retryAfter > Duration.zero
            ? l.lockRetryIn(result.retryAfter.inSeconds)
            : l.lockWrongPin;
    }
  }

  void _startCountdown(Duration wait) {
    _countdown?.cancel();
    final end = DateTime.now().add(wait);
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = end.difference(DateTime.now());
      if (!mounted) return t.cancel();
      final l = AppLocalizations.of(context);
      if (left.isNegative) {
        t.cancel();
        _entry.currentState?.showError(null);
      } else {
        _entry.currentState?.showError(l.lockRetryIn(left.inSeconds + 1));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final vault = context.watch<LockableVault>();
    final shuffle = context.watch<SettingsStore>().paranoia.shuffleKeys;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const IconBadge(
                    icon: Icons.lock_rounded,
                    size: 72,
                    circle: true,
                  ),
                  const SizedBox(height: 20),
                  PinEntry(
                    key: _entry,
                    title: l.lockTitle,
                    subtitle: l.lockEnterPin,
                    shuffle: shuffle,
                    busyLabel: l.lockChecking,
                    onSubmit: _submit,
                    extra: vault.biometricsEnabled
                        ? TextButton.icon(
                            onPressed: _biometric,
                            icon: const Icon(Icons.fingerprint_rounded),
                            label: Text(l.lockBiometric),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
