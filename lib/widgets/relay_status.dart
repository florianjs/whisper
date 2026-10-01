import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/relay_service.dart';
import '../data/tor_service.dart';
import '../l10n/app_localizations.dart';
import '../logic/relays.dart';
import '../theme/tokens.dart';
import 'ui.dart';

/// Null when no Tor service is provided (widget tests).
TorService? watchTor(BuildContext context) {
  try {
    return context.watch<TorService>();
  } on ProviderNotFoundException {
    return null;
  }
}

Color _colorFor(AppPalette c, RelayHealth h) => switch (h) {
  RelayHealth.online => c.success,
  RelayHealth.connecting => c.warning,
  RelayHealth.offline => c.danger,
};

/// Compact connection indicator; tap for the per-relay list.
class RelayStatusPill extends StatelessWidget {
  const RelayStatusPill({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final relays = context.watch<RelayService>();
    final tor = watchTor(context);
    final torPending = tor != null && tor.wanted && tor.state != TorState.ready;
    final viaTor = tor != null && tor.wanted && tor.state == TorState.ready;
    final health = torPending ? RelayHealth.connecting : relays.health;
    final disguised = tor?.level?.disguised ?? false;
    final label = torPending
        ? (tor.state == TorState.failed
              ? l.relayTorFailed
              : disguised
              ? l.relayTorDisguising
              : l.relayTorStarting)
        : switch (health) {
            RelayHealth.online => l.relayOnline(
              relays.connectedCount,
              relays.relays.length,
            ),
            RelayHealth.connecting => l.relayConnecting,
            RelayHealth.offline => l.relayOffline,
          };

    final c = context.c;
    final color = _colorFor(c, health);
    return Material(
      color: color.withValues(alpha: c.isDark ? 0.12 : 0.09),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => showAppSheet<void>(
          context,
          scrollable: true,
          builder: (_) => ChangeNotifierProvider.value(
            value: relays,
            child: const _RelaysSheet(),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulsingDot(color: color, pulsing: health != RelayHealth.online),
              const SizedBox(width: 7),
              if (viaTor) ...[
                Icon(
                  disguised
                      ? Icons.theater_comedy_outlined
                      : Icons.shield_moon_outlined,
                  size: 14,
                  color: c.accent,
                  semanticLabel: disguised ? l.connDisguised : l.connProtected,
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: AnimatedSwitcher(
                  duration: AppMotion.normal,
                  child: Text(
                    label,
                    key: ValueKey(label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelMedium?.copyWith(color: c.fg),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelaysSheet extends StatelessWidget {
  const _RelaysSheet();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final service = context.watch<RelayService>();
    final c = context.c;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.relaysTitle, style: context.text.titleLarge),
          const SizedBox(height: 8),
          Text(
            watchTor(context)?.state == TorState.ready
                ? l.relaysIntroTor
                : l.relaysIntro,
            style: context.text.bodyMedium?.copyWith(color: c.muted),
          ),
          const SizedBox(height: 16),
          if (watchTor(context) case final tor?
              when tor.state == TorState.ready) ...[
            _ConnectionLevel(disguised: tor.level?.disguised ?? false),
            const SizedBox(height: 12),
          ],
          SectionCard(
            margin: EdgeInsets.zero,
            children: [
              for (final entry in service.relays.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      _PulsingDot(
                        color: entry.value ? c.success : c.faint,
                        pulsing: false,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          relayLabel(entry.key),
                          style: context.text.bodyLarge,
                        ),
                      ),
                      Text(
                        entry.value ? l.relayUp : l.relayDown,
                        style: context.text.bodySmall?.copyWith(
                          color: entry.value ? c.success : c.muted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (service.connectedCount < service.relays.length)
            TextButton.icon(
              onPressed: service.reconnectNow,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: Text(l.relaysRetry),
            ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color, required this.pulsing});

  final Color color;
  final bool pulsing;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_PulsingDot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.pulsing && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.pulsing && _c.isAnimating) {
      _c.animateTo(1, duration: const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = widget.pulsing ? _c.value : 1.0;
        return AnimatedContainer(
          duration: AppMotion.normal,
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.45 + 0.55 * t),
          ),
        );
      },
    );
  }
}

/// "Protected" / "Disguised" in plain words: no transport jargon.
class _ConnectionLevel extends StatelessWidget {
  const _ConnectionLevel({required this.disguised});

  final bool disguised;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            icon: disguised
                ? Icons.theater_comedy_outlined
                : Icons.shield_moon_outlined,
            size: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  disguised ? l.connDisguised : l.connProtected,
                  style: context.text.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  disguised ? l.connDisguisedBody : l.connProtectedBody,
                  style: context.text.bodySmall?.copyWith(color: c.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
