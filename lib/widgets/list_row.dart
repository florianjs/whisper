import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/tokens.dart';

/// "14:02" today, "Mar 3" otherwise.
String shortWhen(BuildContext context, DateTime time) {
  final locale = Localizations.localeOf(context).toString();
  final now = DateTime.now();
  final sameDay =
      time.year == now.year && time.month == now.month && time.day == now.day;
  return sameDay
      ? DateFormat.Hm(locale).format(time)
      : DateFormat.MMMd(locale).format(time);
}

/// Rounded-square tinted icon, for groups and channels (people get circles).
class TintedAvatar extends StatelessWidget {
  const TintedAvatar({
    super.key,
    required this.seed,
    required this.icon,
    this.size = 48,
  });

  /// Hex string; its first byte picks the color.
  final String seed;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color =
        avatarPalette[int.parse(seed.substring(0, 2), radix: 16) %
            avatarPalette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.34),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: c.isDark ? 0.34 : 0.26),
            color.withValues(alpha: c.isDark ? 0.14 : 0.10),
          ],
        ),
      ),
      child: Icon(
        icon,
        color: c.isDark ? color : Color.lerp(color, Colors.black, 0.25),
        size: size * 0.5,
      ),
    );
  }
}

/// One row of the home list: avatar, title (+ optional icon), one-line
/// preview, time.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.leading,
    required this.title,
    required this.preview,
    required this.onTap,
    this.when,
    this.titleIcon,
    this.previewColor,
    this.highlight = false,
  });

  final Widget leading;
  final String title;
  final String preview;
  final String? when;
  final VoidCallback onTap;

  /// Small icon after the title (private channel lock…).
  final IconData? titleIcon;
  final Color? previewColor;

  /// Pending invite: accent preview.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleMedium,
                          ),
                        ),
                        if (titleIcon != null) ...[
                          const SizedBox(width: 6),
                          Icon(titleIcon, size: 14, color: c.faint),
                        ],
                        const Spacer(),
                        if (when != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            when!,
                            style: context.text.bodySmall?.copyWith(
                              color: c.faint,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium?.copyWith(
                        color: previewColor ?? (highlight ? c.accent : c.muted),
                        fontWeight: highlight ? FontWeight.w600 : null,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
