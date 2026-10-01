import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/identity_store.dart';
import '../l10n/app_localizations.dart';
import '../data/relay_service.dart';
import '../logic/contact_code.dart';
import '../logic/identity.dart';
import 'scan_screen.dart';
import '../theme/tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/avatar.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  /// Explicit paste: reading the clipboard on open would trigger iOS's paste
  /// permission prompt every time and read data the user didn't offer.
  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && mounted) _controller.text = text;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final me = context.read<IdentityStore>().identity?.publicKey;
    final input = _controller.text.trim();
    final contact = parseContactCode(input);
    final peer = contact?.pubkey;
    String? error;
    if (input.isNotEmpty && peer == null) error = l.newChatInvalid;
    if (peer != null && peer == me) error = l.newChatSelf;
    final ok = peer != null && error == null;

    final c = context.c;
    return Scaffold(
      appBar: AppBar(title: Text(l.newChat)),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.newChatSubtitle,
                style: context.text.bodyMedium?.copyWith(color: c.muted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                maxLines: 3,
                minLines: 1,
                style: TextStyle(
                  color: c.fg,
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: l.newChatHint,
                  errorText: error,
                  errorMaxLines: 2,
                  suffixIcon: IconButton(
                    tooltip: l.paste,
                    onPressed: _paste,
                    icon: Icon(Icons.content_paste_rounded, color: c.muted),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: l.scanQr,
                icon: Icons.qr_code_scanner_rounded,
                variant: ButtonVariant.ghost,
                expand: true,
                onPressed: () async {
                  final scanned = await scanContactCode(context);
                  if (scanned == null || !context.mounted) return;
                  _controller.text = encodeContactCode(
                    scanned.pubkey,
                    scanned.relays,
                  );
                },
              ),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: AppMotion.normal,
                switchInCurve: AppMotion.curve,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SizeTransition(sizeFactor: animation, child: child),
                ),
                child: ok
                    ? Container(
                        key: ValueKey(peer),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(
                            color: c.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Avatar(pubkey: peer, size: 48),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                usernameFor(peer),
                                overflow: TextOverflow.ellipsis,
                                style: context.text.titleMedium,
                              ),
                            ),
                            Icon(Icons.check_circle_rounded, color: c.success),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const Spacer(),
              AppButton(
                label: l.newChatStart,
                expand: true,
                onPressed: ok
                    ? () {
                        context.read<RelayService>().rememberInboxRelays(
                          peer,
                          contact!.relays,
                        );
                        context.pushReplacement('/chat/$peer');
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
