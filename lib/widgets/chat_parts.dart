import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/message.dart';
import '../theme/tokens.dart';
import 'chat_image.dart';

// Building blocks shared by 1:1 chats, groups and channels.

/// App bar title: avatar, name, one-line subtitle. Tappable when [onTap] is
/// set (opens the info screen).
class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.avatar,
    required this.title,
    required this.subtitle,
    this.subtitleIcon,
    this.subtitleIconColor,
    this.onTap,
  });

  final Widget avatar;
  final String title;
  final String subtitle;
  final IconData? subtitleIcon;
  final Color? subtitleIconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium,
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      if (subtitleIcon != null) ...[
                        Icon(
                          subtitleIcon,
                          size: 12,
                          color: subtitleIconColor ?? c.muted,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: c.muted,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.tail,
    required this.animate,
    required this.onRetry,
    this.blur = false,
    this.sender,
  });

  final Message message;
  final bool tail;
  final bool animate;
  final VoidCallback onRetry;
  final bool blur;

  /// Author label above incoming group bubbles (first of a run only).
  final Widget? sender;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.c;
    final mine = message.fromMe;
    final failed = message.status == MessageStatus.failed;
    final image = message.image != null;
    final time = DateFormat.Hm(
      Localizations.localeOf(context).toString(),
    ).format(message.time);
    const r = Radius.circular(AppRadius.lg);
    const small = Radius.circular(6);
    final fg = mine ? c.onAccent : c.fg;

    final bubble = GestureDetector(
      onTap: failed ? onRetry : null,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        // Consecutive bubbles sit tight; a run ends with breathing room.
        margin: EdgeInsets.only(top: 1, bottom: tail ? 10 : 1),
        padding: image
            ? const EdgeInsets.fromLTRB(4, 4, 4, 6)
            : const EdgeInsets.fromLTRB(14, 9, 12, 7),
        decoration: BoxDecoration(
          gradient: mine ? c.accentGradient : null,
          color: mine ? null : c.bubbleIn,
          borderRadius: BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomLeft: mine || !tail ? r : small,
            bottomRight: mine && tail ? small : r,
          ),
          border: failed
              ? Border.all(color: c.danger, width: 1.4)
              : (!mine && !c.isDark ? Border.all(color: c.border) : null),
          boxShadow: c.isDark
              ? null
              : [
                  BoxShadow(
                    color: (mine ? c.accent : Colors.black).withValues(
                      alpha: mine ? 0.16 : 0.03,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (image)
              ChatImage(message: message)
            else
              Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                child: Text(
                  message.text,
                  style: context.text.bodyLarge?.copyWith(
                    color: fg,
                    fontSize: 15.5,
                    height: 1.35,
                  ),
                ),
              ),
            const SizedBox(height: 3),
            Padding(
              padding: image
                  ? const EdgeInsets.only(right: 8)
                  : EdgeInsets.zero,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      color: mine ? c.onAccent.withValues(alpha: 0.7) : c.faint,
                      fontSize: 11,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    _StatusIcon(status: message.status),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final row = Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (sender != null && !mine)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 8, bottom: 4),
            child: sender,
          ),
        blur ? _HoldToReveal(child: bubble) : bubble,
        if (failed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10, right: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, size: 14, color: c.danger),
                const SizedBox(width: 4),
                Text(
                  l.messageFailed,
                  style: TextStyle(color: c.danger, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );

    if (!animate) return row;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.slow,
      curve: AppMotion.curve,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - t)),
          child: Transform.scale(
            scale: 0.94 + 0.06 * t,
            alignment: mine ? Alignment.bottomRight : Alignment.bottomLeft,
            child: child,
          ),
        ),
      ),
      child: row,
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = c.onAccent.withValues(alpha: 0.8);
    final icon = switch (status) {
      MessageStatus.sending => Icon(
        Icons.schedule_rounded,
        size: 13,
        color: color,
      ),
      MessageStatus.sent => Icon(Icons.done_rounded, size: 14, color: color),
      MessageStatus.failed => Icon(
        Icons.error_outline_rounded,
        size: 14,
        color: c.onAccent,
      ),
      MessageStatus.received ||
      MessageStatus.receiving => const SizedBox.shrink(),
    };
    return AnimatedSwitcher(
      duration: AppMotion.normal,
      transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
      child: KeyedSubtree(key: ValueKey(status), child: icon),
    );
  }
}

/// Bottom area holding a composer: page background, floating look.
class _ComposerFrame extends StatelessWidget {
  const _ComposerFrame({
    required this.onAttach,
    required this.field,
    required this.canSend,
    required this.onSend,
    this.focused = false,
  });

  final VoidCallback? onAttach;
  final Widget field;
  final bool canSend;
  final VoidCallback onSend;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      color: c.bg,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: AppMotion.normal,
              curve: AppMotion.curve,
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: focused
                      ? c.accent.withValues(alpha: 0.6)
                      : c.border.withValues(alpha: c.isDark ? 0.6 : 1),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (onAttach != null)
                    IconButton(
                      tooltip: AppLocalizations.of(context).attach,
                      onPressed: onAttach,
                      icon: Icon(
                        Icons.add_photo_alternate_outlined,
                        color: c.muted,
                      ),
                    )
                  else
                    const SizedBox(width: 6),
                  Expanded(child: field),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(enabled: canSend, onPressed: onSend),
        ],
      ),
    );
  }
}

/// Round send button: gradient when there's something to send.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: AppLocalizations.of(context).chatSend,
      child: Semantics(
        button: true,
        enabled: enabled,
        child: AnimatedScale(
          scale: enabled ? 1 : 0.9,
          duration: AppMotion.normal,
          curve: Curves.easeOutBack,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surface2,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox.expand(),
                ),
                AnimatedOpacity(
                  opacity: enabled ? 1 : 0,
                  duration: AppMotion.normal,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: c.accentGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: c.accent.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                Material(
                  type: MaterialType.transparency,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: enabled ? onPressed : null,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: AppMotion.fast,
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          key: ValueKey(enabled),
                          color: enabled ? c.onAccent : c.faint,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.focus,
    required this.canSend,
    this.onAttach,
    this.hint,
    required this.onSend,
    this.obscure = false,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool canSend;

  /// Null hides the attach button (group chats are text only in v1).
  final VoidCallback? onAttach;

  /// Placeholder; defaults to the chat one.
  final String? hint;
  final VoidCallback onSend;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.c;
    return ListenableBuilder(
      listenable: focus,
      builder: (context, _) => _ComposerFrame(
        onAttach: onAttach,
        canSend: canSend,
        onSend: onSend,
        focused: focus.hasFocus,
        field: TextField(
          controller: controller,
          focusNode: focus,
          minLines: 1,
          // Flutter only obscures single-line fields.
          maxLines: obscure ? 1 : 6,
          obscureText: obscure,
          obscuringCharacter: '•',
          textCapitalization: TextCapitalization.sentences,
          // Message content must not feed keyboard learning.
          enableIMEPersonalizedLearning: false,
          style: context.text.bodyLarge?.copyWith(fontSize: 15.5),
          decoration: InputDecoration(
            hintText: hint ?? l.chatInputHint,
            hintStyle: TextStyle(color: c.faint),
            filled: false,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }
}

/// Blurred until pressed and held; blurs again on release.
class _HoldToReveal extends StatefulWidget {
  const _HoldToReveal({required this.child});

  final Widget child;

  @override
  State<_HoldToReveal> createState() => _HoldToRevealState();
}

class _HoldToRevealState extends State<_HoldToReveal> {
  bool _holding = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => setState(() => _holding = true),
      onLongPressEnd: (_) => setState(() => _holding = false),
      onLongPressCancel: () => setState(() => _holding = false),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: _holding ? 0 : 7),
        duration: AppMotion.fast,
        builder: (context, sigma, child) => ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: child,
        ),
        // Blur is visual: hidden content must not leak via semantics either.
        child: ExcludeSemantics(excluding: !_holding, child: widget.child),
      ),
    );
  }
}

/// Composer for the in-app keyboard: plain display widget, no TextField, so
/// no text input connection to the system keyboard ever exists.
class SecureChatComposer extends StatelessWidget {
  const SecureChatComposer({
    super.key,
    required this.text,
    required this.masked,
    required this.canSend,
    required this.onTap,
    this.onAttach,
    this.hint,
    required this.onSend,
  });

  final String text;
  final bool masked;
  final bool canSend;
  final VoidCallback onTap;

  /// Null hides the attach button (group chats are text only in v1).
  final VoidCallback? onAttach;

  /// Placeholder; defaults to the chat one.
  final String? hint;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.c;
    final shown = masked ? '•' * text.characters.length : text;
    return _ComposerFrame(
      onAttach: onAttach,
      canSend: canSend,
      onSend: onSend,
      field: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  text.isEmpty ? (hint ?? l.chatInputHint) : shown,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyLarge?.copyWith(
                    color: text.isEmpty ? c.faint : c.fg,
                    fontSize: 15.5,
                    height: 1.2,
                    // Spacing is for the dots, not the placeholder.
                    letterSpacing: masked && text.isNotEmpty ? 2 : 0,
                  ),
                ),
              ),
              const _Caret(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Caret extends StatefulWidget {
  const _Caret();

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 530),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _c,
    child: Container(
      width: 2,
      height: 20,
      margin: const EdgeInsets.only(left: 1),
      decoration: BoxDecoration(
        color: context.c.accent,
        borderRadius: BorderRadius.circular(1),
      ),
    ),
  );
}

/// Replaces the composer when a choice comes first (request, invitation):
/// a raised card with the explanation and its actions.
class ChatDecisionBar extends StatelessWidget {
  const ChatDecisionBar({
    super.key,
    required this.lines,
    required this.actions,
    this.footer,
  });

  /// Explanation lines.
  final List<Widget> lines;

  /// Main buttons, laid out side by side.
  final List<Widget> actions;

  /// Secondary, destructive action under the buttons (e.g. Block).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: c.isDark ? 0.4 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...lines,
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: actions[i]),
              ],
            ],
          ),
          if (footer != null) ...[const SizedBox(height: 4), footer!],
        ],
      ),
    );
  }
}

/// Centered explanation line inside a [ChatDecisionBar] or notice.
class ChatBarText extends StatelessWidget {
  const ChatBarText(this.text, {super.key, this.strong = false});

  final String text;

  /// Primary color (e.g. a channel description) instead of muted.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: context.text.bodyMedium?.copyWith(
        color: strong ? context.c.fg : context.c.muted,
      ),
    );
  }
}

/// Read-only footer in place of the composer (e.g. removed from a group).
class ChatNoticeBar extends StatelessWidget {
  const ChatNoticeBar({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: c.muted),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(color: c.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
