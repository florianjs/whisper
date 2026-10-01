import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../data/channel_store.dart';
import '../data/group_store.dart';
import '../data/identity_store.dart';
import '../data/lockable_vault.dart';
import '../data/message_store.dart';
import '../data/profile_store.dart';
import '../data/relay_service.dart';
import '../logic/contact_code.dart';
import '../data/settings_store.dart';
import '../data/update_service.dart';
import '../l10n/app_localizations.dart';
import '../logic/identity.dart';
import '../logic/secure_platform.dart';
import '../theme/tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/avatar.dart';
import '../widgets/channel_tile.dart';
import '../widgets/conversation_tile.dart';
import '../widgets/group_tile.dart';
import '../widgets/panic_sheet.dart';
import '../widgets/relay_status.dart';
import '../widgets/ui.dart';
import '../widgets/update_sheet.dart';

enum _Filter { all, chats, groups, channels }

/// Conversation list: search, filters, then chats / groups / channels by
/// most recent activity.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.c;
    final identity = context.watch<IdentityStore>().identity;
    final store = context.watch<MessageStore>();
    final groups = context.watch<GroupStore>();
    final channels = context.watch<ChannelStore>();
    final all = _items(store, groups, channels);
    final query = _search.text.trim().toLowerCase();
    final items = [
      for (final i in all)
        if ((_filter == _Filter.all || i.kind == _filter) &&
            (query.isEmpty || i.name.toLowerCase().contains(query)))
          i,
    ];
    final requestCount =
        store.requests.length +
        groups.groupsWith(GroupStatus.pending).length +
        channels.channelsWith(ChannelStatus.pending).length;
    if (identity == null) return const Scaffold();

    final Widget body;
    if (!store.loaded) {
      body = const Center(
        key: ValueKey('loading'),
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    } else if (all.isEmpty) {
      body = EmptyState(
        key: const ValueKey('empty'),
        icon: Icons.forum_outlined,
        title: l.homeEmptyTitle,
        body: l.homeEmptyBody,
        action: TextButton.icon(
          onPressed: () => _showMyId(context, identity),
          icon: const Icon(Icons.qr_code_rounded, size: 20),
          label: Text(l.myId),
        ),
      );
    } else if (items.isEmpty) {
      body = EmptyState(
        key: const ValueKey('no-results'),
        icon: query.isEmpty ? Icons.inbox_outlined : Icons.search_off_rounded,
        title: query.isEmpty ? l.filterEmpty : l.searchNoResults,
      );
    } else {
      body = ExcludeSemantics(
        key: const ValueKey('list'),
        excluding: context
            .watch<SettingsStore>()
            .paranoia
            .hideFromAccessibility,
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 4, bottom: 112),
          itemCount: items.length,
          itemBuilder: (context, i) => items[i].tile,
        ),
      );
    }

    return Scaffold(
      floatingActionButton: _NewFab(
        label: l.newChat,
        onPressed: () => _startSomething(context),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.appTitle, style: context.text.headlineMedium),
                        const SizedBox(height: 6),
                        const RelayStatusPill(),
                      ],
                    ),
                  ),
                  if (context.watch<LockableVault>().isEnabled)
                    IconButton(
                      tooltip: l.lockNow,
                      onPressed: context.read<LockableVault>().lock,
                      icon: Icon(Icons.lock_outline_rounded, color: c.muted),
                    ),
                  IconButton(
                    tooltip: l.panicTooltip,
                    onPressed: () => showPanicSheet(context),
                    icon: Icon(Icons.shield_outlined, color: c.danger),
                  ),
                  IconButton(
                    tooltip: l.settingsTitle,
                    onPressed: () => context.push('/settings'),
                    icon: Icon(Icons.settings_outlined, color: c.muted),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: l.myId,
                    child: InkResponse(
                      onTap: () => _showMyId(context, identity),
                      radius: 26,
                      child: Avatar(pubkey: identity.publicKey, size: 40),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
              child: Text(
                context.watch<ProfileStore>().myName ?? identity.username,
                style: context.text.bodySmall?.copyWith(color: c.faint),
              ),
            ),
            AnimatedSize(
              duration: AppMotion.normal,
              curve: AppMotion.curve,
              child: context.watch<UpdateService>().hasUpdate
                  ? const UpdateRow()
                  : const SizedBox(width: double.infinity),
            ),
            AnimatedSize(
              duration: AppMotion.normal,
              curve: AppMotion.curve,
              child: requestCount == 0
                  ? const SizedBox(width: double.infinity, height: 12)
                  : _RequestsRow(count: requestCount),
            ),
            if (all.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: AppSearchField(
                  controller: _search,
                  hint: l.searchHint,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final f in _Filter.values) ...[
                      FilterPill(
                        label: switch (f) {
                          _Filter.all => l.filterAll,
                          _Filter.chats => l.filterChats,
                          _Filter.groups => l.filterGroups,
                          _Filter.channels => l.filterChannels,
                        },
                        selected: _filter == f,
                        onTap: () => setState(() => _filter = f),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: AnimatedSwitcher(
                duration: AppMotion.normal,
                switchInCurve: AppMotion.curve,
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 1:1 chats, groups and channels, most recent activity first.
  List<({int at, _Filter kind, String name, Widget tile})> _items(
    MessageStore store,
    GroupStore groups,
    ChannelStore channels,
  ) {
    return [
      for (final c in store.conversations)
        (
          at: c.last.createdAt,
          kind: _Filter.chats,
          name: store.displayName(c.peer),
          tile: ConversationTile(key: ValueKey(c.peer), conversation: c),
        ),
      for (final g in [
        ...groups.groupsWith(GroupStatus.active),
        ...groups.groupsWith(GroupStatus.removed),
      ])
        (
          at: groups.activityOf(g.state.id),
          kind: _Filter.groups,
          name: g.state.name,
          tile: GroupTile(key: ValueKey(g.state.id), entry: g),
        ),
      for (final c in channels.channelsWith(ChannelStatus.active))
        (
          at: channels.activityOf(c.pk),
          kind: _Filter.channels,
          name: c.meta.name,
          tile: ChannelTile(key: ValueKey(c.pk), entry: c),
        ),
    ]..sort((a, b) => b.at.compareTo(a.at));
  }

  void _startSomething(BuildContext context) {
    final l = AppLocalizations.of(context);
    void go(BuildContext sheetContext, String path) {
      Navigator.pop(sheetContext);
      context.push(path);
    }

    showAppSheet<void>(
      context,
      scrollable: true,
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(l.startSomething, style: context.text.titleLarge),
            ),
            SheetAction(
              icon: Icons.person_add_alt_1_rounded,
              title: l.newChat,
              subtitle: l.newChatSubtitle,
              onTap: () => go(sheetContext, '/new'),
            ),
            SheetAction(
              icon: Icons.group_add_rounded,
              title: l.newGroup,
              subtitle: l.newGroupSubtitle,
              onTap: () => go(sheetContext, '/group/new'),
            ),
            SheetAction(
              icon: Icons.campaign_outlined,
              title: l.newChannel,
              subtitle: l.newChannelSubtitle,
              onTap: () => go(sheetContext, '/channel/new'),
            ),
            SheetAction(
              icon: Icons.qr_code_scanner_rounded,
              title: l.joinChannel,
              subtitle: l.joinChannelSubtitle,
              onTap: () => go(sheetContext, '/channel/join'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMyId(BuildContext context, Identity identity) {
    final l = AppLocalizations.of(context);
    final c = context.c;
    // Carries my inbox relays so a new contact can reach me right away.
    final code = encodeContactCode(
      identity.publicKey,
      context.read<RelayService>().relays.keys.toList(),
    );
    showAppSheet<void>(
      context,
      scrollable: true,
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(pubkey: identity.publicKey, size: 72),
            const SizedBox(height: 14),
            Text(
              context.read<ProfileStore>().myName ?? identity.username,
              style: context.text.titleLarge,
            ),
            if (context.read<ProfileStore>().myName != null)
              Text(
                identity.username,
                style: context.text.bodySmall?.copyWith(color: c.muted),
              ),
            const SizedBox(height: 6),
            Text(
              l.myIdBody,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: c.muted),
            ),
            const SizedBox(height: 20),
            // White quiet zone: scanners need contrast.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: [
                  BoxShadow(
                    color: c.accent.withValues(alpha: 0.18),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: QrImageView(
                data: code,
                size: 220,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l.myIdQrHint,
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(color: c.faint),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: SelectableText(
                identity.npub,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.fg,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              expand: true,
              variant: ButtonVariant.secondary,
              icon: Icons.copy_rounded,
              label: l.copyId,
              onPressed: () async {
                // Public ID, not a secret: plain clipboard, no auto-clear.
                await SecurePlatform.copyPlain(code);
                if (!sheetContext.mounted) return;
                ScaffoldMessenger.of(
                  sheetContext,
                ).showSnackBar(SnackBar(content: Text(l.idCopied)));
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Gradient extended FAB.
class _NewFab extends StatelessWidget {
  const _NewFab({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final radius = BorderRadius.circular(AppRadius.lg);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: c.accentGradient,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: c.accent.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_rounded, color: c.onAccent, size: 20),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: context.text.labelLarge?.copyWith(
                    color: c.onAccent,
                    fontWeight: FontWeight.w700,
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

class _RequestsRow extends StatelessWidget {
  const _RequestsRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Material(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => context.push('/requests'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.mark_email_unread_outlined, color: c.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.requestsRow(count),
                    style: context.text.titleSmall?.copyWith(color: c.fg),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
