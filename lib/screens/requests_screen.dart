import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/channel_store.dart';
import '../data/group_store.dart';
import '../data/message_store.dart';
import '../data/settings_store.dart';
import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import '../widgets/channel_tile.dart';
import '../widgets/conversation_tile.dart';
import '../widgets/group_tile.dart';
import '../widgets/ui.dart';

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final requests = context.watch<MessageStore>().requests;
    final invites = context.watch<GroupStore>().groupsWith(GroupStatus.pending);
    final channelInvites = context.watch<ChannelStore>().channelsWith(
      ChannelStatus.pending,
    );
    final hide = context.watch<SettingsStore>().paranoia.hideFromAccessibility;
    return Scaffold(
      appBar: AppBar(title: Text(l.requestsTitle)),
      body: AnimatedSwitcher(
        duration: AppMotion.normal,
        child: requests.isEmpty && invites.isEmpty && channelInvites.isEmpty
            ? EmptyState(
                icon: Icons.mark_email_read_outlined,
                title: l.requestsEmpty,
              )
            : ExcludeSemantics(
                excluding: hide,
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final g in invites) GroupTile(entry: g),
                    for (final c in channelInvites) ChannelTile(entry: c),
                    for (final c in requests) ConversationTile(conversation: c),
                  ],
                ),
              ),
      ),
    );
  }
}
