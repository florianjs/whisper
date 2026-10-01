import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';

/// Shared building blocks of the design: every screen composes these instead
/// of styling raw containers, so spacing, radii and colors stay consistent.

/// Modal bottom sheet with the app's shape, drag handle and safe area.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool scrollable = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: scrollable,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: builder(sheetContext),
      ),
    ),
  );
}

/// Icon on a tinted rounded square (or circle).
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.color,
    this.size = 40,
    this.circle = false,
  });

  final IconData icon;

  /// Defaults to the accent.
  final Color? color;
  final double size;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.c.accent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: context.c.isDark ? 0.16 : 0.11),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: tint, size: size * 0.5),
    );
  }
}

/// One choice in an action sheet: tinted icon, title, optional subtitle.
class SheetAction extends StatelessWidget {
  const SheetAction({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            IconBadge(icon: icon, color: danger ? c.danger : null, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.titleMedium?.copyWith(
                      color: danger ? c.danger : c.fg,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: context.text.bodySmall?.copyWith(color: c.muted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small uppercase caption above a group of rows.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.padding});

  final String text;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        text.toUpperCase(),
        style: context.text.labelSmall?.copyWith(color: context.c.muted),
      ),
    );
  }
}

/// Rounded card grouping rows (settings-style), with thin inner dividers.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.children,
    this.label,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
    this.divided = true,
  });

  final String? label;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;
  final bool divided;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0 && divided) {
        rows.add(Divider(indent: 68, endIndent: 0, color: c.border));
      }
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) SectionLabel(label!),
        Padding(
          padding: margin,
          child: Material(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            clipBehavior: Clip.antiAlias,
            child: Column(children: rows),
          ),
        ),
      ],
    );
  }
}

/// Row inside a [SectionCard]: tinted icon, title, subtitle, trailing.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
    this.chevron = false,
  });

  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  /// Show a chevron when there's no explicit trailing (navigates somewhere).
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (icon != null) ...[
              IconBadge(
                icon: icon!,
                color: danger ? c.danger : iconColor,
                size: 36,
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: danger ? c.danger : c.fg,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: context.text.bodySmall?.copyWith(color: c.muted),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ] else if (chevron) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: c.faint),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pill-shaped search input.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(100),
      borderSide: BorderSide.none,
    );
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: context.text.bodyLarge,
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          fillColor: c.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          prefixIcon: Icon(Icons.search_rounded, color: c.faint, size: 22),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close_rounded, color: c.muted, size: 20),
                  onPressed: () {
                    controller.clear();
                    onChanged?.call('');
                  },
                ),
          border: pill,
          enabledBorder: pill,
          focusedBorder: pill.copyWith(
            borderSide: BorderSide(color: c.accent, width: 1.4),
          ),
        ),
      ),
    );
  }
}

/// Animated selectable chip for horizontal filter rows.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.curve,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? c.fg : c.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: selected ? c.fg : c.border),
          ),
          child: AnimatedDefaultTextStyle(
            duration: AppMotion.normal,
            style: context.text.labelLarge!.copyWith(
              fontSize: 14,
              color: selected ? c.bg : c.muted,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

/// Centered illustration-like empty state.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    c.accent.withValues(alpha: 0.22),
                    c.accentAlt.withValues(alpha: 0.08),
                  ],
                ),
              ),
              child: Icon(icon, color: c.accent, size: 38),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.text.titleLarge,
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(color: c.muted),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Soft tinted notice box (info / warning / danger).
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.color,
  });

  final String text;
  final IconData icon;

  /// Defaults to the accent.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.c.accent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: context.c.isDark ? 0.10 : 0.07),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tint.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tint, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall?.copyWith(color: context.c.fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog asking for one line of text; the typed text, or null if cancelled.
/// The dialog owns its controller: disposing it as soon as `showDialog`
/// returns would break the closing animation, which still renders the field.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  String? initial,
  String? hint,
  String? help,
  int? maxLength,
  TextCapitalization capitalization = TextCapitalization.none,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextPrompt(
      title: title,
      initial: initial,
      hint: hint,
      help: help,
      maxLength: maxLength,
      capitalization: capitalization,
    ),
  );
}

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({
    required this.title,
    required this.initial,
    required this.hint,
    required this.help,
    required this.maxLength,
    required this.capitalization,
  });

  final String title;
  final String? initial;
  final String? hint;
  final String? help;
  final int? maxLength;
  final TextCapitalization capitalization;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: widget.maxLength,
            enableIMEPersonalizedLearning: false,
            textCapitalization: widget.capitalization,
            decoration: InputDecoration(hintText: widget.hint),
            onSubmitted: (text) => Navigator.pop(context, text),
          ),
          if (widget.help != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.help!,
              style: context.text.bodySmall?.copyWith(color: context.c.muted),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(l.save),
        ),
      ],
    );
  }
}
