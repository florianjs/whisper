import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Numbered two-column word grid, blurred until [revealed]. Words fade in with
/// a stagger when revealed.
class SeedGrid extends StatelessWidget {
  const SeedGrid({
    super.key,
    required this.words,
    required this.revealed,
    required this.onReveal,
    required this.revealHint,
  });

  final List<String> words;
  final bool revealed;
  final VoidCallback onReveal;
  final String revealHint;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final half = (words.length / 2).ceil();
    Widget column(int start, int end) => Expanded(
      child: Column(
        children: [
          for (var i = start; i < end; i++)
            _WordTile(index: i, word: words[i], revealed: revealed),
        ],
      ),
    );

    final grid = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          column(0, half),
          const SizedBox(width: 8),
          column(half, words.length),
        ],
      ),
    );

    return GestureDetector(
      onTap: revealed ? null : onReveal,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: revealed ? 0 : 9),
            duration: const Duration(milliseconds: 450),
            curve: AppMotion.curve,
            builder: (context, sigma, child) => ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: child,
            ),
            // Blur is visual only: without this, accessibility services
            // (screen readers, but also any app granted a11y access) read the
            // words before the user chose to reveal them.
            child: ExcludeSemantics(excluding: !revealed, child: grid),
          ),
          IgnorePointer(
            child: AnimatedOpacity(
              duration: AppMotion.normal,
              opacity: revealed ? 0 : 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.surface,
                        boxShadow: [
                          BoxShadow(
                            color: c.accent.withValues(alpha: 0.25),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.visibility_outlined,
                        color: c.accent,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      revealHint,
                      textAlign: TextAlign.center,
                      style: context.text.titleSmall?.copyWith(color: c.fg),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WordTile extends StatelessWidget {
  const _WordTile({
    required this.index,
    required this.word,
    required this.revealed,
  });

  final int index;
  final String word;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // Stagger: each tile starts a little after the previous one.
    final delay = revealed ? index * 18 : 0;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: revealed ? 1 : 0.35),
      duration: Duration(milliseconds: 260 + delay),
      curve: Interval(
        revealed ? delay / (260 + delay) : 0,
        1,
        curve: Curves.easeOut,
      ),
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: c.faint,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                word,
                style: context.text.titleMedium?.copyWith(fontSize: 15.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmented progress for multi-step flows (create → verify).
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.step, required this.of});

  /// 1-based current step.
  final int step;
  final int of;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= of; i++) ...[
          if (i > 1) const SizedBox(width: 6),
          AnimatedContainer(
            duration: AppMotion.slow,
            curve: AppMotion.curve,
            width: i == step ? 28 : 16,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: i <= step ? c.accentGradient : null,
              color: i <= step ? null : c.surface2,
            ),
          ),
        ],
      ],
    );
  }
}
