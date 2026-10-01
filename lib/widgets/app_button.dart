import 'package:flutter/material.dart';
import '../theme/tokens.dart';

enum ButtonVariant { primary, secondary, ghost, danger }

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.expand = false,
    this.loading = false,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final IconData? icon;
  final bool expand;
  final bool loading;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  void _press(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Color? box;
    Gradient? gradient;
    late Color fg;
    BoxBorder? border;
    switch (widget.variant) {
      case ButtonVariant.primary:
        gradient = c.accentGradient;
        fg = c.onAccent;
      case ButtonVariant.secondary:
        box = c.surface2;
        fg = c.fg;
      case ButtonVariant.ghost:
        box = Colors.transparent;
        fg = c.fg;
        border = Border.all(color: c.border);
      case ButtonVariant.danger:
        box = c.dangerSoft;
        fg = c.danger;
    }

    final enabled = widget.onPressed != null && !widget.loading;
    final radius = BorderRadius.circular(AppRadius.md + 2);
    final child = AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      child: AnimatedOpacity(
        duration: AppMotion.normal,
        opacity: widget.onPressed == null ? 0.4 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: box,
            gradient: gradient,
            borderRadius: radius,
            border: border,
            boxShadow: gradient == null || !enabled
                ? null
                : [
                    BoxShadow(
                      color: c.accent.withValues(alpha: c.isDark ? 0.28 : 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: enabled ? widget.onPressed : null,
              onHighlightChanged: _press,
              splashColor: fg.withValues(alpha: 0.12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 54),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  child: AnimatedSwitcher(
                    duration: AppMotion.fast,
                    child: widget.loading
                        ? Center(
                            key: const ValueKey('loading'),
                            widthFactor: 1,
                            child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: fg,
                              ),
                            ),
                          )
                        : Row(
                            key: const ValueKey('label'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.icon != null) ...[
                                Icon(widget.icon, size: 19, color: fg),
                                const SizedBox(width: 10),
                              ],
                              Flexible(
                                child: Text(
                                  widget.label,
                                  textAlign: TextAlign.center,
                                  style: context.text.labelLarge?.copyWith(
                                    color: fg,
                                    fontSize: 16,
                                    fontWeight:
                                        widget.variant == ButtonVariant.primary
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return widget.expand
        ? SizedBox(width: double.infinity, child: child)
        : child;
  }
}
