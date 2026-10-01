import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/tokens.dart';
import 'shake.dart';

/// PIN entry on Whisper's own keypad: the system keyboard never sees it,
/// accessibility services can't read it, digits optionally shuffled per
/// display (paranoia) so recorded touch positions reveal nothing.
class PinEntry extends StatefulWidget {
  const PinEntry({
    super.key,
    required this.title,
    required this.onSubmit,
    this.subtitle,
    this.shuffle = false,
    this.busyLabel,
    this.extra,
    this.maxLength = 12,
    this.minLength = 6,
  });

  final String title;
  final String? subtitle;

  /// Returns an error to show (the entry clears and shakes), or null.
  final Future<String?> Function(String pin) onSubmit;
  final bool shuffle;
  final String? busyLabel;

  /// Optional widget under the pad (e.g. biometric button).
  final Widget? extra;
  final int maxLength;
  final int minLength;

  @override
  State<PinEntry> createState() => PinEntryState();
}

class PinEntryState extends State<PinEntry> {
  final _shakeKey = GlobalKey<ShakeState>();
  String _pin = '';
  String? _error;
  bool _busy = false;
  late final List<String> _digits = () {
    // Phone-keypad order: 1-9, then 0 on the last row.
    final d = [for (var i = 1; i <= 9; i++) '$i', '0'];
    if (widget.shuffle) d.shuffle(Random.secure());
    return d;
  }();

  void _press(String d) {
    if (_busy || _pin.length >= widget.maxLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = null;
    });
  }

  void _backspace() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (_busy || _pin.length < widget.minLength) return;
    setState(() => _busy = true);
    final error = await widget.onSubmit(_pin);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _pin = '';
      _error = error;
    });
    if (error != null) {
      HapticFeedback.heavyImpact();
      _shakeKey.currentState?.shake();
    }
  }

  /// Lets the parent show an error without a submit (e.g. lockout timer).
  void showError(String? error) => setState(() => _error = error);

  @override
  Widget build(BuildContext context) {
    final rows = [
      _digits.sublist(0, 3),
      _digits.sublist(3, 6),
      _digits.sublist(6, 9),
    ];
    final c = context.c;
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: context.text.headlineSmall,
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.subtitle!,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: c.muted),
            ),
          ],
          const SizedBox(height: 28),
          Shake(
            key: _shakeKey,
            child: SizedBox(
              height: 18,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < max(widget.minLength, _pin.length); i++)
                    AnimatedContainer(
                      duration: AppMotion.fast,
                      curve: AppMotion.curve,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: i < _pin.length ? 16 : 12,
                      height: i < _pin.length ? 16 : 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: i < _pin.length ? c.accentGradient : null,
                        color: i < _pin.length ? null : c.surface2,
                        border: i < _pin.length
                            ? null
                            : Border.all(color: c.border, width: 1.5),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 20,
            child: AnimatedSwitcher(
              duration: AppMotion.normal,
              child: _busy && widget.busyLabel != null
                  ? Text(
                      widget.busyLabel!,
                      key: const ValueKey('busy'),
                      style: context.text.bodyMedium?.copyWith(color: c.muted),
                    )
                  : Text(
                      _error ?? '',
                      key: ValueKey(_error),
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(
                        color: c.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          for (final row in rows)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final d in row) _Key(label: d, onTap: () => _press(d)),
              ],
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Key(
                icon: Icons.backspace_outlined,
                onTap: _backspace,
                subtle: true,
              ),
              _Key(label: _digits[9], onTap: () => _press(_digits[9])),
              _Key(
                icon: _busy ? null : Icons.arrow_forward_rounded,
                busy: _busy,
                onTap: _pin.length >= widget.minLength ? _submit : null,
                accent: true,
              ),
            ],
          ),
          if (widget.extra != null) ...[
            const SizedBox(height: 12),
            widget.extra!,
          ],
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    this.label,
    this.icon,
    required this.onTap,
    this.subtle = false,
    this.accent = false,
    this.busy = false,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool subtle;
  final bool accent;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final enabled = onTap != null;
    final radius = BorderRadius.circular(AppRadius.lg + 2);
    final fg = accent && enabled ? c.onAccent : c.fg;
    return Padding(
      padding: const EdgeInsets.all(7),
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.curve,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: accent && enabled ? c.accentGradient : null,
          color: accent
              ? (enabled ? null : c.surface2)
              : (subtle ? Colors.transparent : c.surface),
          border: accent || subtle ? null : Border.all(color: c.border),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            splashColor: c.accent.withValues(alpha: 0.18),
            highlightColor: c.accentSoft,
            child: SizedBox(
              width: 78,
              height: 64,
              child: Center(
                child: busy
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: c.onAccent,
                        ),
                      )
                    : icon != null
                    ? Icon(icon, color: accent && !enabled ? c.faint : fg)
                    : Text(
                        label!,
                        style: TextStyle(
                          color: c.fg,
                          fontSize: 26,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
