import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import '../widgets/app_button.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  /// Fade + rise for a slice of the intro timeline, so blocks arrive in turn.
  Widget _stagger(double start, double end, Widget child) {
    final anim = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.c;
    return Scaffold(
      body: Stack(
        children: [
          // Soft accent glow behind the hero.
          Positioned(
            top: -160,
            left: -80,
            right: -80,
            child: _stagger(
              0,
              0.8,
              Container(
                height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      c.accent.withValues(alpha: c.isDark ? 0.22 : 0.16),
                      c.accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  _stagger(0, 0.6, const _Logo()),
                  const SizedBox(height: 28),
                  _stagger(
                    0.1,
                    0.65,
                    Text(
                      l.appTitle,
                      style: context.text.displaySmall?.copyWith(
                        fontSize: 44,
                        letterSpacing: -1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _stagger(
                    0.2,
                    0.75,
                    Text(
                      l.appTagline,
                      textAlign: TextAlign.center,
                      style: context.text.bodyLarge?.copyWith(color: c.muted),
                    ),
                  ),
                  const Spacer(flex: 4),
                  _stagger(
                    0.4,
                    0.9,
                    AppButton(
                      label: l.welcomeCreate,
                      icon: Icons.auto_awesome_rounded,
                      expand: true,
                      onPressed: () => context.go('/create'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _stagger(
                    0.5,
                    1,
                    AppButton(
                      label: l.welcomeRestore,
                      variant: ButtonVariant.ghost,
                      expand: true,
                      onPressed: () => context.go('/restore'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _stagger(
                    0.6,
                    1,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.verified_user_outlined,
                            size: 16,
                            color: c.faint,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l.welcomeFootnote,
                            style: context.text.bodySmall?.copyWith(
                              color: c.faint,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The app logo, with a soft accent glow behind it.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: c.accent.withValues(alpha: c.isDark ? 0.35 : 0.25),
            blurRadius: 48,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Image.asset(
        'assets/branding/splash.png',
        semanticLabel: 'Whisper',
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
