import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/channel_store.dart';
import '../data/settings_store.dart';
import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'list_row.dart';

class ChannelAvatar extends StatelessWidget {
  const ChannelAvatar({super.key, required this.pk, this.size = 48});

  final String pk;
  final double size;

  @override
  Widget build(BuildContext context) =>
      TintedAvatar(seed: pk, icon: Icons.campaign_rounded, size: size);
}

class ChannelTile extends StatelessWidget {
  const ChannelTile({super.key, required this.entry});

  final ChannelEntry entry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final store = context.watch<ChannelStore>();
    final last = store.lastIn(entry.pk);
    final time = DateTime.fromMillisecondsSinceEpoch(
      store.activityOf(entry.pk) * 1000,
    );
    final hidden = context.watch<SettingsStore>().paranoia.blurHistory;
    final preview = entry.status == ChannelStatus.pending
        ? l.channelInviteRow
        : last == null
        ? l.channelBadge
        : (hidden ? '•••••' : last.text);

    return ListRow(
      onTap: () => context.push('/channel/${entry.pk}'),
      leading: ChannelAvatar(pk: entry.pk, size: 48),
      title: entry.meta.name,
      titleIcon: entry.meta.public ? null : Icons.lock_rounded,
      preview: preview,
      when: shortWhen(context, time),
      highlight: entry.status == ChannelStatus.pending,
      previewColor: last?.status == PostStatus.failed ? context.c.danger : null,
    );
  }
}
