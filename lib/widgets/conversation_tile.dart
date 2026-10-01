import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/message_store.dart';
import '../data/settings_store.dart';
import '../l10n/app_localizations.dart';
import '../models/message.dart';
import '../theme/tokens.dart';
import 'avatar.dart';
import 'list_row.dart';

class ConversationTile extends StatelessWidget {
  const ConversationTile({super.key, required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final last = conversation.last;
    // Blurred history also hides previews: the list is readable at a glance.
    final hidden = context.watch<SettingsStore>().paranoia.blurHistory;
    final text = hidden
        ? '•••••'
        : (last.image != null ? l.photoPreview : last.text);
    final preview = last.fromMe ? l.youPrefix(text) : text;

    return ListRow(
      onTap: () => context.push('/chat/${conversation.peer}'),
      leading: Avatar(pubkey: conversation.peer, size: 48),
      title: context.watch<MessageStore>().displayName(conversation.peer),
      preview: preview,
      when: shortWhen(context, last.time),
      previewColor: last.status == MessageStatus.failed
          ? context.c.danger
          : null,
    );
  }
}
