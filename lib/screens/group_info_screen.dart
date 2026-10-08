import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/group_store.dart';
import '../data/identity_store.dart';
import '../data/message_store.dart';
import '../l10n/app_localizations.dart';
import '../logic/secure_platform.dart';
import '../logic/links.dart';
import '../logic/group.dart';
import '../theme/tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/avatar.dart';
import '../widgets/group_tile.dart';
import '../widgets/ui.dart';

/// Members, and admin actions (rename / add / remove) or leave.
class GroupInfoScreen extends StatelessWidget {
  const GroupInfoScreen({super.key, required this.groupId});

  final String groupId;

  Future<void> _rename(BuildContext context, String current) async {
    final l = AppLocalizations.of(context);
    final name = await showTextPrompt(
      context,
      title: l.groupRename,
      initial: current,
      hint: l.groupName,
      maxLength: 60,
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    await context.read<GroupStore>().rename(groupId, name);
  }

  Future<void> _leave(BuildContext context, String name) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.groupLeave),
        content: Text(l.groupLeaveConfirm(name)),
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
            child: Text(l.groupLeave),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<GroupStore>().leave(groupId);
    if (context.mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final me = context.watch<IdentityStore>().identity?.publicKey;
    final entry = context.watch<GroupStore>().group(groupId);
    final names = context.watch<MessageStore>();
    if (entry == null || me == null) return Scaffold(appBar: AppBar());
    final state = entry.state;
    final isAdmin = state.admin == me && entry.status == GroupStatus.active;
    final members = state.members.toList()
      ..sort((a, b) {
        // Admin first, then me, then by name.
        int rank(String p) => p == state.admin ? 0 : (p == me ? 1 : 2);
        final r = rank(a).compareTo(rank(b));
        return r != 0
            ? r
            : names.displayName(a).compareTo(names.displayName(b));
      });

    final c = context.c;
    return Scaffold(
      appBar: AppBar(title: Text(l.groupInfo)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: 8),
          Center(child: GroupAvatar(groupId: groupId, size: 88)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    state.name,
                    textAlign: TextAlign.center,
                    style: context.text.headlineSmall,
                  ),
                ),
                if (isAdmin)
                  IconButton(
                    tooltip: l.groupRename,
                    onPressed: () => _rename(context, state.name),
                    icon: Icon(Icons.edit_outlined, size: 18, color: c.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l.groupMembers(state.members.length),
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: c.muted),
          ),
          const SizedBox(height: 24),
          SectionCard(
            children: [
              SettingsTile(
                icon: Icons.link_rounded,
                title: l.groupCopyLink,
                onTap: () async {
                  // Opens the group for its members only; still, no reason
                  // to leave it in the clipboard.
                  await SecurePlatform.copySensitive(GroupLink.encode(groupId));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l.groupLinkCopied)));
                },
              ),
              if (isAdmin && state.members.length < GroupState.maxMembers)
                SettingsTile(
                  icon: Icons.person_add_alt_1_rounded,
                  title: l.groupAddMembers,
                  onTap: () => context.push('/group/$groupId/add'),
                ),
              for (final p in members)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Avatar(pubkey: p, size: 40),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          p == me ? l.groupYou : names.displayName(p),
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (p == state.admin)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: c.accentSoft,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            l.groupAdmin,
                            style: context.text.labelMedium?.copyWith(
                              color: c.accent,
                            ),
                          ),
                        ),
                      if (isAdmin && p != me)
                        IconButton(
                          tooltip: l.groupRemoveMember,
                          onPressed: () => context
                              .read<GroupStore>()
                              .removeMember(groupId, p),
                          icon: Icon(
                            Icons.remove_circle_outline_rounded,
                            color: c.danger,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (state.admin == me)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: NoticeCard(text: l.groupNoAdminLeave),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppButton(
                label: l.groupLeave,
                icon: Icons.logout_rounded,
                variant: ButtonVariant.danger,
                expand: true,
                onPressed: () => _leave(context, state.name),
              ),
            ),
        ],
      ),
    );
  }
}
