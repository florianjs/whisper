import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/group_store.dart';
import '../data/message_store.dart';
import '../data/settings_store.dart';
import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/avatar.dart';
import '../widgets/chat_parts.dart';
import '../widgets/group_tile.dart';
import '../widgets/secure_keyboard.dart';
import '../widgets/ui.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _secure = SecureTextController();
  bool _keyboardOpen = false;

  late final Set<String> _initialIds = context
      .read<GroupStore>()
      .messagesIn(widget.groupId)
      .map((m) => m.id)
      .toSet();

  @override
  void initState() {
    super.initState();
    _initialIds;
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

  Future<void> _send() async {
    final text = _draft;
    if (text.trim().isEmpty) return;
    HapticFeedback.selectionClick();
    _paranoiaKeyboard ? _secure.clear() : _input.clear();
    await context.read<GroupStore>().send(widget.groupId, text);
  }

  void _openSecureKeyboard() {
    FocusScope.of(context).unfocus();
    setState(() => _keyboardOpen = true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final groups = context.watch<GroupStore>();
    final names = context.watch<MessageStore>();
    final entry = groups.group(widget.groupId);
    if (entry == null) {
      // Left, refused or wiped while open.
      return Scaffold(appBar: AppBar());
    }
    final messages = groups.messagesIn(widget.groupId).reversed.toList();
    final paranoia = context.watch<SettingsStore>().paranoia;
    final canSend = _draft.trim().isNotEmpty;
    final active = entry.status == GroupStatus.active;
    final keyboardOpen = paranoia.inAppKeyboard && _keyboardOpen && active;

    return PopScope(
      canPop: !keyboardOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _keyboardOpen = false);
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: ChatHeader(
            onTap: entry.status == GroupStatus.pending
                ? null
                : () => context.push('/group/${widget.groupId}/info'),
            avatar: GroupAvatar(groupId: widget.groupId, size: 38),
            title: entry.state.name,
            subtitle: l.groupMembers(entry.state.members.length),
            subtitleIcon: Icons.lock_rounded,
            subtitleIconColor: context.c.success,
          ),
          actions: [
            if (entry.status != GroupStatus.pending)
              IconButton(
                tooltip: l.groupInfo,
                onPressed: () => context.push('/group/${widget.groupId}/info'),
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
                    child: messages.isEmpty
                        ? EmptyState(
                            icon: Icons.groups_outlined,
                            title: l.chatEncrypted,
                            body: l.groupEmpty,
                          )
                        : ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(14, 16, 14, 6),
                            itemCount: messages.length,
                            itemBuilder: (context, i) {
                              final m = messages[i];
                              final newer = i > 0 ? messages[i - 1] : null;
                              final older = i + 1 < messages.length
                                  ? messages[i + 1]
                                  : null;
                              // A run = consecutive messages by one author.
                              final tail =
                                  newer == null || newer.peer != m.peer;
                              final head =
                                  older == null || older.peer != m.peer;
                              return ChatBubble(
                                key: ValueKey(m.id),
                                message: m,
                                tail: tail,
                                animate: !_initialIds.contains(m.id),
                                blur: paranoia.blurHistory,
                                onRetry: () => groups.retry(m.id),
                                sender: head && !m.fromMe
                                    ? _SenderLabel(
                                        pubkey: m.peer,
                                        name: names.displayName(m.peer),
                                      )
                                    : null,
                              );
                            },
                          ),
                  ),
                ),
              ),
              switch (entry.status) {
                GroupStatus.pending => _InviteBar(entry: entry),
                GroupStatus.removed => ChatNoticeBar(
                  text: l.groupRemoved,
                  icon: Icons.person_off_outlined,
                ),
                GroupStatus.active => ExcludeSemantics(
                  excluding: paranoia.hideFromAccessibility,
                  child: paranoia.inAppKeyboard
                      ? SecureChatComposer(
                          text: _secure.value,
                          masked: paranoia.maskInput,
                          canSend: canSend,
                          onTap: _openSecureKeyboard,
                          onSend: _send,
                        )
                      : ChatComposer(
                          controller: _input,
                          focus: _focus,
                          canSend: canSend,
                          obscure: paranoia.maskInput,
                          onSend: _send,
                        ),
                ),
              },
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

class _SenderLabel extends StatelessWidget {
  const _SenderLabel({required this.pubkey, required this.name});

  final String pubkey;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Avatar(pubkey: pubkey, size: 18),
        const SizedBox(width: 6),
        Text(
          name,
          style: context.text.labelMedium?.copyWith(color: context.c.muted),
        ),
      ],
    );
  }
}

/// Invitation from someone I haven't accepted: explicit choice first.
class _InviteBar extends StatelessWidget {
  const _InviteBar({required this.entry});

  final GroupEntry entry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final groups = context.read<GroupStore>();
    final admin = context.read<MessageStore>().displayName(entry.state.admin);
    return ChatDecisionBar(
      lines: [ChatBarText(l.groupInvite(admin))],
      actions: [
        AppButton(
          label: l.requestRefuse,
          variant: ButtonVariant.secondary,
          onPressed: () async {
            await groups.leave(entry.state.id);
            if (context.mounted) context.pop();
          },
        ),
        AppButton(
          label: l.requestAccept,
          onPressed: () {
            HapticFeedback.selectionClick();
            groups.accept(entry.state.id);
          },
        ),
      ],
    );
  }
}
