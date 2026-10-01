import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/group_store.dart';
import '../data/message_store.dart';
import '../data/settings_store.dart';
import '../l10n/app_localizations.dart';
import '../models/message.dart';
import '../theme/tokens.dart';
import 'list_row.dart';

/// Group picture: no photos in v1, a tinted icon derived from the group id.
class GroupAvatar extends StatelessWidget {
  const GroupAvatar({super.key, required this.groupId, this.size = 48});

  final String groupId;
  final double size;

  @override
  Widget build(BuildContext context) =>
      TintedAvatar(seed: groupId, icon: Icons.groups_rounded, size: size);
}

class GroupTile extends StatelessWidget {
  const GroupTile({super.key, required this.entry});

  final GroupEntry entry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final groups = context.watch<GroupStore>();
    final names = context.watch<MessageStore>();
    final id = entry.state.id;
    final last = groups.lastIn(id);
    final time = DateTime.fromMillisecondsSinceEpoch(
      groups.activityOf(id) * 1000,
    );
    final hidden = context.watch<SettingsStore>().paranoia.blurHistory;

    final String preview;
    if (entry.status == GroupStatus.pending) {
      preview = l.groupInviteRow;
    } else if (last == null) {
      preview = l.groupMembers(entry.state.members.length);
    } else {
      final text = hidden ? '•••••' : last.text;
      preview = last.fromMe
          ? l.youPrefix(text)
          : l.groupNamePrefix(names.displayName(last.peer), text);
    }

    return ListRow(
      onTap: () => context.push('/group/$id'),
      leading: GroupAvatar(groupId: id, size: 48),
      title: entry.state.name,
      preview: preview,
      when: shortWhen(context, time),
      highlight: entry.status == GroupStatus.pending,
      previewColor: last?.status == MessageStatus.failed
          ? context.c.danger
          : null,
    );
  }
}
