import 'package:flutter/material.dart';

/// Design tokens — single source of truth for color/style. Colors depend on
/// the brightness: read them with `context.c`, never hard-code them.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.fg,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.accentAlt,
    required this.onAccent,
    required this.bubbleIn,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Brightness brightness;

  /// Page background.
  final Color bg;

  /// Cards, sheets, input fields.
  final Color surface;

  /// Raised elements on a surface (chips, incoming bubbles, pressed states).
  final Color surface2;
  final Color border;
  final Color fg;
  final Color muted;
  final Color faint;
  final Color accent;

  /// Second stop of the accent gradient.
  final Color accentAlt;
  final Color onAccent;
  final Color bubbleIn;
  final Color success;
  final Color warning;
  final Color danger;

  bool get isDark => brightness == Brightness.dark;

  /// Outgoing bubbles, primary buttons, FAB.
  LinearGradient get accentGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentAlt],
  );

  /// Tinted background behind accent icons / selected chips.
  Color get accentSoft => accent.withValues(alpha: isDark ? 0.16 : 0.10);
  Color get dangerSoft => danger.withValues(alpha: isDark ? 0.14 : 0.08);
  Color get bubbleOut => accent;

  static const dark = AppPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF0E0F13),
    surface: Color(0xFF17181E),
    surface2: Color(0xFF212229),
    border: Color(0xFF2B2D36),
    fg: Color(0xFFF3F4F7),
    muted: Color(0xFF9B9DAA),
    faint: Color(0xFF5F626E),
    accent: Color(0xFF8E7DFF),
    accentAlt: Color(0xFF6A8DFF),
    onAccent: Color(0xFFFFFFFF),
    bubbleIn: Color(0xFF212229),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
  );

  static const light = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF5F5F8),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFECEDF2),
    border: Color(0xFFE1E2E9),
    fg: Color(0xFF15161B),
    muted: Color(0xFF5F6270),
    faint: Color(0xFF9EA1AD),
    accent: Color(0xFF6E5BF0),
    accentAlt: Color(0xFF4C7DF5),
    onAccent: Color(0xFFFFFFFF),
    bubbleIn: Color(0xFFFFFFFF),
    success: Color(0xFF0E9F6E),
    warning: Color(0xFFD97706),
    danger: Color(0xFFE5484D),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: mix(bg, other.bg),
      surface: mix(surface, other.surface),
      surface2: mix(surface2, other.surface2),
      border: mix(border, other.border),
      fg: mix(fg, other.fg),
      muted: mix(muted, other.muted),
      faint: mix(faint, other.faint),
      accent: mix(accent, other.accent),
      accentAlt: mix(accentAlt, other.accentAlt),
      onAccent: mix(onAccent, other.onAccent),
      bubbleIn: mix(bubbleIn, other.bubbleIn),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      danger: mix(danger, other.danger),
    );
  }
}

extension AppThemeContext on BuildContext {
  /// Current palette (dark or light). Falls back on the brightness when the
  /// theme wasn't built by [buildTheme] (bare MaterialApp, e.g. in tests).
  AppPalette get c {
    final theme = Theme.of(this);
    return theme.extension<AppPalette>() ??
        (theme.brightness == Brightness.dark
            ? AppPalette.dark
            : AppPalette.light);
  }

  TextTheme get text => Theme.of(this).textTheme;
}

/// Corner radii.
abstract final class AppRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 28.0;
}

/// Durations and curves: one rhythm across the app.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
  static const curve = Curves.easeOutCubic;
}

/// Avatar backgrounds; picked deterministically from the pubkey. Readable on
/// both themes.
const avatarPalette = <Color>[
  Color(0xFF8E7DFF), // violet (accent)
  Color(0xFF60A5FA), // blue
  Color(0xFFF472B6), // pink
  Color(0xFFFB923C), // orange
  Color(0xFF34D399), // green
  Color(0xFFF5B82E), // amber
  Color(0xFF22D3EE), // cyan
  Color(0xFF84CC16), // lime
];
