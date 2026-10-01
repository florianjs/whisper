import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/identity_store.dart';
import '../l10n/app_localizations.dart';
import '../logic/secure_platform.dart';
import '../theme/tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/seed_grid.dart';
import '../widgets/ui.dart';

class CreateIdentityScreen extends StatefulWidget {
  const CreateIdentityScreen({super.key});

  @override
  State<CreateIdentityScreen> createState() => _CreateIdentityScreenState();
}

class _CreateIdentityScreenState extends State<CreateIdentityScreen> {
  bool _revealed = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    SecurePlatform.acquireSecureScreen();
    final store = context.read<IdentityStore>();
    if (store.draftMnemonic == null) store.startCreation();
  }

  @override
  void dispose() {
    SecurePlatform.releaseSecureScreen();
    super.dispose();
  }

  void _leave() {
    context.read<IdentityStore>().discardDraft();
    context.go('/');
  }

  Future<void> _copy(String mnemonic) async {
    final l = AppLocalizations.of(context);
    await SecurePlatform.copySensitive(mnemonic);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.seedCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final store = context.watch<IdentityStore>();
    final mnemonic = store.draftMnemonic;
    final draft = store.draftIdentity;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: l.back,
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _leave,
          ),
          title: const StepProgress(step: 1, of: 2),
          centerTitle: true,
          actions: const [SizedBox(width: 56)],
        ),
        body: SafeArea(
          top: false,
          child: AnimatedSwitcher(
            duration: AppMotion.slow,
            switchInCurve: AppMotion.curve,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween(begin: 0.96, end: 1.0).animate(anim),
                child: child,
              ),
            ),
            child: mnemonic == null || draft == null
                ? _Generating(label: l.createGenerating)
                : _content(l, mnemonic, draft.username),
          ),
        ),
      ),
    );
  }

  Widget _content(AppLocalizations l, String mnemonic, String username) {
    final c = context.c;
    return ListView(
      key: const ValueKey('content'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                c.accent.withValues(alpha: c.isDark ? 0.18 : 0.12),
                c.accentAlt.withValues(alpha: c.isDark ? 0.06 : 0.04),
              ],
            ),
            border: Border.all(color: c.accent.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.createUsernameLabel,
                style: context.text.labelSmall?.copyWith(color: c.muted),
              ),
              const SizedBox(height: 8),
              _UsernameReveal(username: username),
              const SizedBox(height: 10),
              Text(
                l.createUsernameCaption,
                style: context.text.bodyMedium?.copyWith(color: c.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            const IconBadge(icon: Icons.key_rounded, size: 36),
            const SizedBox(width: 12),
            Expanded(child: Text(l.seedTitle, style: context.text.titleLarge)),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          l.seedIntro,
          style: context.text.bodyMedium?.copyWith(color: c.muted),
        ),
        const SizedBox(height: 20),
        SeedGrid(
          words: mnemonic.split(' '),
          revealed: _revealed,
          revealHint: l.seedRevealHint,
          onReveal: () => setState(() => _revealed = true),
        ),
        const SizedBox(height: 12),
        AnimatedOpacity(
          duration: AppMotion.normal,
          opacity: _revealed ? 1 : 0,
          child: Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: l.seedCopy,
              icon: Icons.copy_rounded,
              variant: ButtonVariant.secondary,
              onPressed: _revealed ? () => _copy(mnemonic) : null,
            ),
          ),
        ),
        const SizedBox(height: 20),
        NoticeCard(
          text: l.seedWarning,
          icon: Icons.warning_amber_rounded,
          color: c.warning,
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          value: _saved,
          onChanged: _revealed
              ? (v) => setState(() => _saved = v ?? false)
              : null,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: Text(l.seedSavedCheckbox, style: context.text.bodyLarge),
        ),
        const SizedBox(height: 16),
        AppButton(
          label: l.continueLabel,
          expand: true,
          onPressed: _saved ? () => context.go('/create/verify') : null,
        ),
      ],
    );
  }
}

class _Generating extends StatelessWidget {
  const _Generating({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      key: const ValueKey('generating'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              const SizedBox(
                width: 76,
                height: 76,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              Icon(Icons.key_rounded, color: c.accent, size: 30),
            ],
          ),
          const SizedBox(height: 20),
          Text(label, style: context.text.bodyLarge?.copyWith(color: c.muted)),
        ],
      ),
    );
  }
}

/// Username "decodes" letter by letter, like a key being resolved.
class _UsernameReveal extends StatelessWidget {
  const _UsernameReveal({required this.username});

  final String username;

  static const _glyphs = 'abcdefghijklmnopqrstuvwxyz0123456789';

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      curve: AppMotion.curve,
      builder: (context, t, _) {
        final settled = (username.length * t).floor();
        final buffer = StringBuffer();
        for (var i = 0; i < username.length; i++) {
          final c = username[i];
          if (i < settled || c == '-') {
            buffer.write(c);
          } else {
            // Deterministic scramble from position + progress, no Random.
            buffer.write(_glyphs[(i * 7 + (t * 40).floor()) % _glyphs.length]);
          }
        }
        return Text(
          buffer.toString(),
          style: context.text.headlineMedium?.copyWith(color: context.c.accent),
        );
      },
    );
  }
}
