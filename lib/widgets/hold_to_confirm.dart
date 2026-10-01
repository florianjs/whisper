import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/tokens.dart';

/// Destructive action that fires only after a continuous press of [duration].
/// Releasing early rewinds the ring. Fast enough for an emergency, but a stray
/// tap in a pocket can't trigger it.
class HoldToConfirm extends StatefulWidget {
  const HoldToConfirm({
    super.key,
    required this.label,
    required this.holdingLabel,
    required this.onConfirmed,
    this.duration = const Duration(milliseconds: 1500),
  });

  final String label;
  final String holdingLabel;
  final VoidCallback onConfirmed;
  final Duration duration;

  @override
  State<HoldToConfirm> createState() => _HoldToConfirmState();
}

class _HoldToConfirmState extends State<HoldToConfirm>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed && !_fired) {
            _fired = true;
            HapticFeedback.heavyImpact();
            widget.onConfirmed();
          }
        });
  bool _fired = false;
  int _lastTick = 0;

  @override
  void initState() {
    super.initState();
    // A light tick each quarter so the hold is felt, not just seen.
    _c.addListener(() {
      final tick = (_c.value * 4).floor();
      if (_c.status == AnimationStatus.forward && tick > _lastTick) {
        HapticFeedback.selectionClick();
      }
      _lastTick = tick;
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _start() {
    if (_fired) return;
    _c.forward();
  }

  void _cancel() {
    if (_fired) return;
    _c.animateBack(0, duration: const Duration(milliseconds: 250));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _start(),
      onTapUp: (_) => _cancel(),
      onTapCancel: _cancel,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final holding = _c.value > 0;
          final palette = context.c;
          final fg = _c.value > 0.5 ? palette.onAccent : palette.danger;
          return Container(
            height: 64,
            decoration: BoxDecoration(
              color: palette.dangerSoft,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: palette.danger.withValues(alpha: 0.5)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _c.value,
                  child: ColoredBox(color: palette.danger),
                ),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_forever_rounded, color: fg),
                      const SizedBox(width: 8),
                      Text(
                        holding ? widget.holdingLabel : widget.label,
                        style: context.text.labelLarge?.copyWith(
                          color: fg,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
