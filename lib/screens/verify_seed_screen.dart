import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/identity_store.dart';
import '../l10n/app_localizations.dart';
import '../logic/secure_platform.dart';
import '../logic/seed_challenge.dart';
import '../theme/tokens.dart';
import '../widgets/seed_grid.dart';
import '../widgets/shake.dart';
import '../widgets/ui.dart';

class VerifySeedScreen extends StatefulWidget {
  const VerifySeedScreen({super.key});

  @override
  State<VerifySeedScreen> createState() => _VerifySeedScreenState();
}

class _VerifySeedScreenState extends State<VerifySeedScreen> {
  // One key per step: AnimatedSwitcher keeps the outgoing step mounted during
  // the transition, so a shared GlobalKey would be duplicated.
  final _shakeKeys = <int, GlobalKey<ShakeState>>{};
  GlobalKey<ShakeState> _shakeKey(int step) =>
      _shakeKeys.putIfAbsent(step, GlobalKey<ShakeState>.new);
  List<String> _words = const [];
  List<ChallengeItem> _items = const [];
  int _step = 0;
  bool _wrong = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    SecurePlatform.acquireSecureScreen();
    final mnemonic = context.read<IdentityStore>().draftMnemonic;
    if (mnemonic == null) {
      // Reached without a draft (e.g. process restart): start over.
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
      return;
    }
    _words = mnemonic.split(' ');
    _items = buildChallenge(_words);
  }

  @override
  void dispose() {
    SecurePlatform.releaseSecureScreen();
    super.dispose();
  }

  Future<void> _answer(String word) async {
    if (_saving) return;
    final item = _items[_step];
    if (word != _words[item.index]) {
      HapticFeedback.heavyImpact();
      _shakeKey(_step).currentState?.shake();
      setState(() => _wrong = true);
      return;
    }
    HapticFeedback.selectionClick();
    if (_step < _items.length - 1) {
      setState(() {
        _step++;
        _wrong = false;
      });
      return;
    }
    setState(() => _saving = true);
    // Persisting flips hasIdentity; the router redirect takes us home.
    await context.read<IdentityStore>().confirmDraft();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_items.isEmpty) return const Scaffold();
    final item = _items[_step];
    final c = context.c;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.verifyTitle),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: StepProgress(step: 2, of: 2),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Progress(step: _step, total: _items.length),
              const SizedBox(height: 8),
              Text(
                l.verifyProgress(_step + 1, _items.length),
                style: context.text.bodySmall?.copyWith(color: c.muted),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: AppMotion.curve,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0.15, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Column(
                    key: ValueKey(_step),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l.verifyPrompt(item.index + 1),
                        style: context.text.headlineSmall,
                      ),
                      const SizedBox(height: 28),
                      Shake(
                        key: _shakeKey(_step),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final option in item.options)
                              _OptionChip(
                                word: option,
                                onTap: () => _answer(option),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      AnimatedOpacity(
                        duration: AppMotion.normal,
                        opacity: _wrong ? 1 : 0,
                        child: NoticeCard(
                          text: l.verifyWrong,
                          icon: Icons.error_outline_rounded,
                          color: c.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: _saving ? null : () => context.pop(),
                style: TextButton.styleFrom(foregroundColor: c.muted),
                child: Text(l.verifyShowAgain),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: AppMotion.slow,
              curve: AppMotion.curve,
              height: 6,
              decoration: BoxDecoration(
                gradient: i <= step ? context.c.accentGradient : null,
                color: i <= step ? null : context.c.surface2,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({required this.word, required this.onTap});

  final String word;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final radius = BorderRadius.circular(AppRadius.md);
    return Material(
      color: c.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        highlightColor: c.accentSoft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: c.border),
          ),
          child: Text(
            word,
            style: context.text.titleMedium?.copyWith(fontSize: 17),
          ),
        ),
      ),
    );
  }
}
