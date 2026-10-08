import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/channel_store.dart';
import '../data/message_store.dart';
import '../l10n/app_localizations.dart';
import '../logic/channel.dart';
import '../logic/secure_platform.dart';
import '../theme/tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/avatar.dart';
import '../widgets/channel_tile.dart';
import '../widgets/ui.dart';
import 'new_channel_screen.dart';

class ChannelInfoScreen extends StatelessWidget {
  const ChannelInfoScreen({super.key, required this.pk});

  final String pk;

  Future<void> _edit(BuildContext context, ChannelEntry c) async {
    final l = AppLocalizations.of(context);
    final name = TextEditingController(text: c.meta.name);
    final about = TextEditingController(text: c.meta.about);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.channelEdit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              maxLength: Channel.maxName,
              enableIMEPersonalizedLearning: false,
              decoration: InputDecoration(hintText: l.channelName),
            ),
            TextField(
              controller: about,
              maxLength: Channel.maxAbout,
              maxLines: 3,
              enableIMEPersonalizedLearning: false,
              decoration: InputDecoration(hintText: l.channelAbout),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.save),
          ),
        ],
      ),
    );
    final n = name.text, a = about.text;
    name.dispose();
    about.dispose();
    if (ok != true || n.trim().isEmpty || !context.mounted) return;
    await context.read<ChannelStore>().editMeta(pk, name: n, about: a);
  }

  Future<void> _pickHistory(BuildContext context, ChannelEntry c) async {
    final store = context.read<ChannelStore>();
    final picked = await showAppSheet<bool>(
      context,
      scrollable: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: ChannelHistoryChoice(
          fullHistory: c.meta.fullHistory,
          onChanged: (v) => Navigator.pop(sheetContext, v),
        ),
      ),
    );
    if (picked == null || picked == c.meta.fullHistory) return;
    await store.editMeta(pk, fullHistory: picked);
  }

  Future<void> _inviteContacts(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final messages = context.read<MessageStore>();
    final contacts = [for (final c in messages.conversations) c.peer];
    final picked = await showAppSheet<Set<String>>(
      context,
      scrollable: true,
      builder: (sheetContext) => _ContactPicker(contacts: contacts),
    );
    if (picked == null || picked.isEmpty || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await context.read<ChannelStore>().inviteContacts(pk, picked);
    messenger.showSnackBar(SnackBar(content: Text(l.channelInvitesSent)));
  }

  Future<void> _leave(BuildContext context, String name) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.channelLeave),
        content: Text(l.channelLeaveConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(l.channelLeave),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<ChannelStore>().leave(pk);
    if (context.mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.c;
    final c = context.watch<ChannelStore>().channel(pk);
    if (c == null) return Scaffold(appBar: AppBar());
    // Private channels: only the admin hands out the invite.
    final showInvite = c.mine || c.meta.public;
    final code = c.invite.encode();

    return Scaffold(
      appBar: AppBar(
        title: Text(l.channelInfo),
        actions: [
          if (c.mine)
            IconButton(
              tooltip: l.channelEdit,
              onPressed: () => _edit(context, c),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          Center(child: ChannelAvatar(pk: pk, size: 88)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              c.meta.name,
              textAlign: TextAlign.center,
              style: context.text.headlineSmall,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: p.surface2,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    c.meta.public ? Icons.public_rounded : Icons.lock_rounded,
                    size: 14,
                    color: p.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    c.meta.public ? l.channelPublic : l.channelPrivate,
                    style: context.text.labelMedium?.copyWith(color: p.muted),
                  ),
                ],
              ),
            ),
          ),
          if (c.meta.about.isNotEmpty) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                c.meta.about,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium,
              ),
            ),
          ],
          if (showInvite || c.mine) ...[
            const SizedBox(height: 24),
            SectionCard(
              children: [
                if (showInvite)
                  SettingsTile(
                    icon: Icons.copy_rounded,
                    title: l.channelCopyInvite,
                    onTap: () async {
                      // Holds the read key: sensitive copy, auto-cleared.
                      await SecurePlatform.copySensitive(code);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.channelInviteCopied)),
                      );
                    },
                  ),
                if (c.mine)
                  SettingsTile(
                    icon: Icons.person_add_alt_1_rounded,
                    title: l.channelInviteContacts,
                    chevron: true,
                    onTap: () => _inviteContacts(context),
                  ),
                if (c.mine)
                  SettingsTile(
                    icon: c.meta.fullHistory
                        ? Icons.history_rounded
                        : Icons.update_rounded,
                    title: l.channelHistory,
                    subtitle: c.meta.fullHistory
                        ? l.channelHistoryAll
                        : l.channelHistoryJoin,
                    chevron: true,
                    onTap: () => _pickHistory(context, c),
                  ),
              ],
            ),
          ],
          if (showInvite) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  children: [
                    Text(
                      l.channelInviteBody,
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall?.copyWith(color: p.muted),
                    ),
                    const SizedBox(height: 16),
                    // White quiet zone: scanners need contrast.
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: QrImageView(
                        data: code,
                        size: 200,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: c.mine
                ? NoticeCard(text: l.channelAdminNote, icon: Icons.key_rounded)
                : AppButton(
                    label: l.channelLeave,
                    icon: Icons.logout_rounded,
                    variant: ButtonVariant.danger,
                    expand: true,
                    onPressed: () => _leave(context, c.meta.name),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ContactPicker extends StatefulWidget {
  const _ContactPicker({required this.contacts});

  final List<String> contacts;

  @override
  State<_ContactPicker> createState() => _ContactPickerState();
}

class _ContactPickerState extends State<_ContactPicker> {
  final _picked = <String>{};

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final messages = context.read<MessageStore>();
    final c = context.c;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              l.channelInviteContacts,
              style: context.text.titleLarge,
            ),
          ),
          if (widget.contacts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l.groupNoContacts,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(color: c.muted),
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final p in widget.contacts)
                    CheckboxListTile(
                      value: _picked.contains(p),
                      onChanged: (v) => setState(
                        () => v == true ? _picked.add(p) : _picked.remove(p),
                      ),
                      selected: _picked.contains(p),
                      selectedTileColor: c.accentSoft,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      secondary: Avatar(pubkey: p, size: 44),
                      title: Text(
                        messages.displayName(p),
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleMedium,
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: AppButton(
              label: l.channelInvite,
              expand: true,
              onPressed: _picked.isEmpty
                  ? null
                  : () => Navigator.pop(context, _picked),
            ),
          ),
        ],
      ),
    );
  }
}
