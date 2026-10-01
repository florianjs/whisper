import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/channel_store.dart';
import '../data/message_store.dart';
import '../data/settings_store.dart';
import '../l10n/app_localizations.dart';
import '../logic/channel.dart';
import '../theme/tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/channel_tile.dart';
import '../widgets/chat_parts.dart';
import '../widgets/secure_keyboard.dart';
import '../widgets/ui.dart';

class ChannelScreen extends StatefulWidget {
  const ChannelScreen({super.key, required this.pk});

  final String pk;

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _secure = SecureTextController();
  bool _keyboardOpen = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    _secure.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _secure.dispose();
    super.dispose();
  }

  bool get _paranoiaKeyboard =>
      context.read<SettingsStore>().paranoia.inAppKeyboard;

  String get _draft => _paranoiaKeyboard ? _secure.value : _input.text;

  Future<void> _post() async {
    final text = _draft;
    if (text.trim().isEmpty) return;
    HapticFeedback.selectionClick();
    _paranoiaKeyboard ? _secure.clear() : _input.clear();
    await context.read<ChannelStore>().post(widget.pk, text);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final store = context.watch<ChannelStore>();
    final entry = store.channel(widget.pk);
    if (entry == null) return Scaffold(appBar: AppBar());
    final posts = store.postsIn(widget.pk).reversed.toList();
    final paranoia = context.watch<SettingsStore>().paranoia;
    final canSend = _draft.trim().isNotEmpty;
    final pending = entry.status == ChannelStatus.pending;
    final keyboardOpen = paranoia.inAppKeyboard && _keyboardOpen && entry.mine;

    return PopScope(
      canPop: !keyboardOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _keyboardOpen = false);
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: ChatHeader(
            onTap: pending
                ? null
                : () => context.push('/channel/${widget.pk}/info'),
            avatar: ChannelAvatar(pk: widget.pk, size: 38),
            title: entry.meta.name,
            subtitle: l.channelFollowers,
            subtitleIcon: entry.meta.public
                ? Icons.campaign_outlined
                : Icons.lock_rounded,
          ),
          actions: [
            if (!pending)
              IconButton(
                tooltip: l.channelInfo,
                onPressed: () => context.push('/channel/${widget.pk}/info'),
                icon: const Icon(Icons.info_outline_rounded),
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: keyboardOpen
                      ? () => setState(() => _keyboardOpen = false)
                      : null,
                  child: ExcludeSemantics(
                    excluding: paranoia.hideFromAccessibility,
                    child: posts.isEmpty
                        ? EmptyState(
                            icon: Icons.campaign_outlined,
                            title: l.channelEmptyViewer,
                            body: entry.mine ? l.channelEmptyAdmin : null,
                          )
                        : ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            itemCount: posts.length,
                            itemBuilder: (context, i) => _PostCard(
                              key: ValueKey(posts[i].id),
                              post: posts[i],
                              blur: paranoia.blurHistory,
                              canReact: !pending,
                            ),
                          ),
                  ),
                ),
              ),
              if (pending)
                _InviteBar(entry: entry)
              else if (entry.mine)
                ExcludeSemantics(
                  excluding: paranoia.hideFromAccessibility,
                  child: paranoia.inAppKeyboard
                      ? SecureChatComposer(
                          text: _secure.value,
                          masked: paranoia.maskInput,
                          canSend: canSend,
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            setState(() => _keyboardOpen = true);
                          },
                          onSend: _post,
                          hint: l.channelPostHint,
                        )
                      : ChatComposer(
                          controller: _input,
                          focus: _focus,
                          canSend: canSend,
                          obscure: paranoia.maskInput,
                          onSend: _post,
                          hint: l.channelPostHint,
                        ),
                ),
              AnimatedSize(
                duration: AppMotion.normal,
                curve: AppMotion.curve,
                child: keyboardOpen
                    ? SecureKeyboard(
                        controller: _secure,
                        languageCode: Localizations.localeOf(
                          context,
                        ).languageCode,
                        shuffle: paranoia.shuffleKeys,
                        spaceLabel: l.keyboardSpace,
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    super.key,
    required this.post,
    required this.blur,
    required this.canReact,
  });

  final ChannelPost post;
  final bool blur;
  final bool canReact;

  Future<void> _pick(BuildContext context) async {
    final store = context.read<ChannelStore>();
    final emoji = await showAppSheet<String>(
      context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final e in Channel.emojis)
              Material(
                color: sheetContext.c.surface2,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.pop(sheetContext, e),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Center(
                      child: Text(e, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (emoji != null) await store.react(post.channel, post.id, emoji);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final store = context.watch<ChannelStore>();
    final counts = store.reactionsOf(post.id);
    final mine = store.myReactionOn(post.channel, post.id);
    final failed = post.status == PostStatus.failed;
    final time = DateFormat.MMMd(
      Localizations.localeOf(context).toString(),
    ).add_Hm().format(post.time);

    final c = context.c;
    Widget body = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 16, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: failed
            ? Border.all(color: c.danger, width: 1.4)
            : (c.isDark ? null : Border.all(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.text,
            style: context.text.bodyLarge?.copyWith(
              fontSize: 15.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(time, style: TextStyle(color: c.faint, fontSize: 11.5)),
              if (post.status == PostStatus.sending) ...[
                const SizedBox(width: 6),
                Icon(Icons.schedule_rounded, size: 12, color: c.faint),
              ],
              if (failed) ...[
                const SizedBox(width: 8),
                Icon(Icons.refresh_rounded, size: 13, color: c.danger),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    l.messageFailed,
                    style: TextStyle(color: c.danger, fontSize: 11.5),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
    if (failed) {
      body = GestureDetector(onTap: () => store.retry(post.id), child: body);
    }
    if (blur) body = _Blurred(child: body);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          body,
          if (counts.isNotEmpty || canReact)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in Channel.emojis)
                    if (counts[e] != null)
                      _ReactionChip(
                        emoji: e,
                        count: counts[e]!,
                        selected: mine == e,
                        onTap: canReact
                            ? () => store.react(post.channel, post.id, e)
                            : null,
                      ),
                  if (canReact)
                    Tooltip(
                      message: l.channelReact,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(100),
                        onTap: () => _pick(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: c.border),
                          ),
                          child: Icon(
                            Icons.add_reaction_outlined,
                            size: 16,
                            color: c.muted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.selected,
    this.onTap,
  });

  final String emoji;
  final int count;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.curve,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          color: selected ? c.accentSoft : c.surface2,
          border: Border.all(
            color: selected
                ? c.accent.withValues(alpha: 0.6)
                : Colors.transparent,
          ),
        ),
        child: Text(
          '$emoji $count',
          style: TextStyle(
            color: selected ? c.accent : c.fg,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Blurred until held, like chat history in paranoia mode.
class _Blurred extends StatefulWidget {
  const _Blurred({required this.child});

  final Widget child;

  @override
  State<_Blurred> createState() => _BlurredState();
}

class _BlurredState extends State<_Blurred> {
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
        child: ExcludeSemantics(excluding: !_holding, child: widget.child),
      ),
    );
  }
}

class _InviteBar extends StatelessWidget {
  const _InviteBar({required this.entry});

  final ChannelEntry entry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final store = context.read<ChannelStore>();
    return ChatDecisionBar(
      lines: [
        if (entry.meta.about.isNotEmpty) ...[
          ChatBarText(entry.meta.about, strong: true),
          const SizedBox(height: 8),
        ],
        if (entry.invitedBy != null)
          ChatBarText(
            l.channelInviteFrom(
              context.read<MessageStore>().displayName(entry.invitedBy!),
            ),
          ),
      ],
      actions: [
        AppButton(
          label: l.requestRefuse,
          variant: ButtonVariant.secondary,
          onPressed: () async {
            await store.leave(entry.pk);
            if (context.mounted) context.pop();
          },
        ),
        AppButton(
          label: l.channelJoin,
          onPressed: () {
            HapticFeedback.selectionClick();
            store.accept(entry.pk);
          },
        ),
      ],
    );
  }
}
