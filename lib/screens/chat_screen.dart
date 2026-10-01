import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/message_store.dart';
import '../data/settings_store.dart';
import '../l10n/app_localizations.dart';
import '../logic/identity.dart';
import '../models/message.dart';
import '../theme/tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/avatar.dart';
import '../widgets/chat_image.dart';
import '../widgets/chat_parts.dart';
import 'safety_number_screen.dart';
import '../widgets/secure_keyboard.dart';
import '../widgets/ui.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.peer});

  /// Hex pubkey.
  final String peer;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  /// Paranoia keyboard buffer: never attached to the system IME.
  final _secure = SecureTextController();
  bool _keyboardOpen = false;

  /// Messages already on screen when it opened don't replay the entry
  /// animation; only new ones slide in.
  late final Set<String> _initialIds = context
      .read<MessageStore>()
      .messagesWith(widget.peer)
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
    await context.read<MessageStore>().send(widget.peer, text);
  }

  Future<void> _rename() async {
    final l = AppLocalizations.of(context);
    final store = context.read<MessageStore>();
    final alias = await showTextPrompt(
      context,
      title: l.rename,
      initial: store.aliasOf(widget.peer),
      hint: l.renameHint,
      maxLength: 40,
    );
    if (alias != null) await store.setAlias(widget.peer, alias);
  }

  Future<void> _confirmBlock(String name) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.block_rounded, color: dialogContext.c.danger),
        title: Text(l.blockConfirmTitle(name)),
        content: Text(l.blockConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              l.requestBlock,
              style: TextStyle(color: dialogContext.c.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await context.read<MessageStore>().block(widget.peer);
    messenger.showSnackBar(SnackBar(content: Text(l.requestBlocked(name))));
    if (mounted) context.pop();
  }

  Future<void> _attach() async {
    final l = AppLocalizations.of(context);
    setState(() => _keyboardOpen = false);
    final source = await showAppSheet<ImageSource>(
      context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetAction(
              icon: Icons.photo_library_outlined,
              title: l.photoFromGallery,
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            SheetAction(
              icon: Icons.photo_camera_outlined,
              title: l.photoFromCamera,
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    await pickAndSendImage(context, widget.peer, source);
  }

  void _showMenu(String name) {
    final l = AppLocalizations.of(context);
    void pick(BuildContext sheetContext, VoidCallback action) {
      Navigator.pop(sheetContext);
      action();
    }

    showAppSheet<void>(
      context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetAction(
              icon: Icons.verified_user_outlined,
              title: l.safetyNumber,
              onTap: () => pick(
                sheetContext,
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SafetyNumberScreen(peer: widget.peer),
                  ),
                ),
              ),
            ),
            SheetAction(
              icon: Icons.edit_outlined,
              title: l.rename,
              onTap: () => pick(sheetContext, _rename),
            ),
            SheetAction(
              icon: Icons.block_rounded,
              title: l.requestBlock,
              danger: true,
              onTap: () => pick(sheetContext, () => _confirmBlock(name)),
            ),
          ],
        ),
      ),
    );
  }

  void _openSecureKeyboard() {
    // Make sure the system keyboard is not up at the same time.
    FocusScope.of(context).unfocus();
    setState(() => _keyboardOpen = true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final store = context.watch<MessageStore>();
    final messages = store.messagesWith(widget.peer).reversed.toList();
    final name = store.displayName(widget.peer);
    final verified = store.isVerified(widget.peer);
    final paranoia = context.watch<SettingsStore>().paranoia;
    final canSend = _draft.trim().isNotEmpty;
    final keyboardOpen = paranoia.inAppKeyboard && _keyboardOpen;
    final pending = store.stateOf(widget.peer) == ContactState.pending;

    return PopScope(
      // Back closes our keyboard first, like the system one.
      canPop: !keyboardOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _keyboardOpen = false);
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          actions: [
            IconButton(
              tooltip: l.chatMenu,
              onPressed: () => _showMenu(name),
              icon: const Icon(Icons.more_horiz_rounded),
            ),
            const SizedBox(width: 4),
          ],
          title: ChatHeader(
            avatar: Avatar(pubkey: widget.peer, size: 38),
            title: name,
            onTap: () => _showMenu(name),
            // Any name other than the key-derived one is shown with it: a
            // contact can't pass for someone else by picking their nickname.
            subtitle: name != usernameFor(widget.peer)
                ? usernameFor(widget.peer)
                : verified
                ? l.verified
                : l.chatEncrypted,
            subtitleIcon: verified
                ? Icons.verified_user_rounded
                : Icons.lock_rounded,
            subtitleIconColor: context.c.success,
          ),
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
                            icon: Icons.lock_outline_rounded,
                            title: l.chatEncrypted,
                            body: l.chatEmpty(name),
                          )
                        : ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(14, 16, 14, 6),
                            itemCount: messages.length,
                            itemBuilder: (context, i) {
                              final m = messages[i];
                              // Group consecutive bubbles from the same side.
                              final newer = i > 0 ? messages[i - 1] : null;
                              final tail =
                                  newer == null || newer.fromMe != m.fromMe;
                              return ChatBubble(
                                key: ValueKey(m.id),
                                message: m,
                                tail: tail,
                                animate: !_initialIds.contains(m.id),
                                blur: paranoia.blurHistory,
                                onRetry: () => store.retry(m.id),
                              );
                            },
                          ),
                  ),
                ),
              ),
              if (pending)
                _RequestBar(peer: widget.peer, name: name)
              else
                ExcludeSemantics(
                  excluding: paranoia.hideFromAccessibility,
                  child: paranoia.inAppKeyboard
                      ? SecureChatComposer(
                          text: _secure.value,
                          masked: paranoia.maskInput,
                          canSend: canSend,
                          onTap: _openSecureKeyboard,
                          onSend: _send,
                          onAttach: _attach,
                        )
                      : ChatComposer(
                          controller: _input,
                          focus: _focus,
                          canSend: canSend,
                          obscure: paranoia.maskInput,
                          onSend: _send,
                          onAttach: _attach,
                        ),
                ),
              AnimatedSize(
                duration: AppMotion.normal,
                curve: AppMotion.curve,
                child: keyboardOpen && !pending
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

/// Replaces the composer while a first contact is pending: replying would
/// implicitly accept, so the choice is made explicit first.
class _RequestBar extends StatelessWidget {
  const _RequestBar({required this.peer, required this.name});

  final String peer;
  final String name;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final store = context.read<MessageStore>();
    return ChatDecisionBar(
      lines: [ChatBarText(l.requestBanner(name))],
      actions: [
        AppButton(
          label: l.requestRefuse,
          variant: ButtonVariant.secondary,
          onPressed: () async {
            await store.refuse(peer);
            if (context.mounted) context.pop();
          },
        ),
        AppButton(
          label: l.requestAccept,
          onPressed: () {
            HapticFeedback.selectionClick();
            store.accept(peer);
          },
        ),
      ],
      footer: TextButton.icon(
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          await store.block(peer);
          messenger.showSnackBar(
            SnackBar(content: Text(l.requestBlocked(name))),
          );
          if (context.mounted) context.pop();
        },
        style: TextButton.styleFrom(foregroundColor: context.c.danger),
        icon: const Icon(Icons.block_rounded, size: 18),
        label: Text(l.requestBlock),
      ),
    );
  }
}
