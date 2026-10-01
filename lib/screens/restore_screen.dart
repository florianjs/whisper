import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/identity_store.dart';
import '../l10n/app_localizations.dart';
import '../logic/identity.dart';
import '../logic/secure_platform.dart';
import '../logic/seed_challenge.dart';
import '../theme/tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/ui.dart';

class RestoreScreen extends StatefulWidget {
  const RestoreScreen({super.key});

  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    SecurePlatform.acquireSecureScreen();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    SecurePlatform.releaseSecureScreen();
    _controller.dispose();
    super.dispose();
  }

  List<String> get _tokens => _controller.text
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();

  /// The word being typed, if the cursor sits right after it.
  String get _partial {
    final text = _controller.text;
    if (text.isEmpty || RegExp(r'\s$').hasMatch(text)) return '';
    return _tokens.isEmpty ? '' : _tokens.last;
  }

  void _complete(String word) {
    final text = _controller.text;
    final base = text.substring(0, text.length - _partial.length);
    final next = '$base$word ';
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      // Success flips hasIdentity; the router redirect takes us home.
      await context.read<IdentityStore>().restore(_controller.text);
    } on ArgumentError {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = _tokens;
    final partial = _partial;
    final complete = partial.isEmpty
        ? tokens
        : tokens.sublist(0, tokens.length - 1);
    final unknown = complete.where((w) => !isBip39Word(w)).firstOrNull;
    final rightLength = tokens.length == 12 || tokens.length == 24;
    final valid = rightLength && isValidMnemonic(_controller.text);
    final suggestions = bip39Suggestions(
      partial,
    ).where((w) => w != partial).toList();

    String? error;
    if (unknown != null) {
      error = l.restoreUnknownWord(unknown);
    } else if (rightLength && !valid && partial.isEmpty) {
      error = l.restoreInvalid;
    }

    final c = context.c;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.restoreTitle),
        leading: IconButton(
          tooltip: l.back,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IconBadge(icon: Icons.restore_rounded, size: 40),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      l.restoreIntro,
                      style: context.text.bodyMedium?.copyWith(color: c.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                autofocus: true,
                minLines: 4,
                maxLines: 6,
                // Keep the phrase out of keyboard learning/suggestions.
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                keyboardType: TextInputType.visiblePassword,
                style: context.text.bodyLarge?.copyWith(
                  fontSize: 17,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide(color: c.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide(color: c.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide(color: c.accent, width: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: AppMotion.normal,
                      child: Text(
                        error ?? '',
                        key: ValueKey(error),
                        style: context.text.bodySmall?.copyWith(
                          color: c.danger,
                        ),
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: AppMotion.normal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: valid
                          ? c.success.withValues(alpha: 0.12)
                          : c.surface2,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (valid) ...[
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: c.success,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          l.restoreWordCount(tokens.length),
                          style: context.text.labelMedium?.copyWith(
                            color: valid ? c.success : c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedSize(
                duration: AppMotion.normal,
                curve: AppMotion.curve,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in suggestions)
                      ActionChip(
                        label: Text(s),
                        onPressed: () => _complete(s),
                        backgroundColor: c.accentSoft,
                        side: BorderSide.none,
                        labelStyle: context.text.labelLarge?.copyWith(
                          color: c.accent,
                        ),
                      ),
                  ],
                ),
              ),
              const Spacer(),
              AppButton(
                label: l.restoreAction,
                expand: true,
                loading: _busy,
                onPressed: valid ? _restore : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
