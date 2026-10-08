import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/channel_store.dart';
import '../l10n/app_localizations.dart';
import '../logic/auto_lock.dart';
import '../logic/channel.dart';
import '../theme/tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/channel_tile.dart';
import 'scan_screen.dart';

class JoinChannelScreen extends StatefulWidget {
  const JoinChannelScreen({super.key, this.code});

  /// Prefilled invite (a link tapped in a message).
  final String? code;

  @override
  State<JoinChannelScreen> createState() => _JoinChannelScreenState();
}

class _JoinChannelScreenState extends State<JoinChannelScreen> {
  late final _controller = TextEditingController(text: widget.code);

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await AutoLock.suspendWhile(
      () => Clipboard.getData(Clipboard.kTextPlain),
    );
    if (data?.text != null) _controller.text = data!.text!.trim();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = _controller.text.trim();
    final invite = text.isEmpty ? null : ChannelInvite.parse(text);
    final error = text.isNotEmpty && invite == null
        ? l.channelJoinInvalid
        : null;

    final c = context.c;
    return Scaffold(
      appBar: AppBar(title: Text(l.joinChannel)),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.joinChannelSubtitle,
                style: context.text.bodyMedium?.copyWith(color: c.muted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                maxLines: 3,
                minLines: 1,
                style: TextStyle(
                  color: c.fg,
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: l.channelJoinHint,
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
                  final scanned = await scanCode(context, ChannelInvite.parse);
                  if (scanned == null || !mounted) return;
                  _controller.text = scanned.encode();
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
                child: invite == null
                    ? const SizedBox(width: double.infinity)
                    : Container(
                        key: ValueKey(invite.channelPk),
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
                            ChannelAvatar(pk: invite.channelPk),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                invite.name,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.titleMedium,
                              ),
                            ),
                            Icon(Icons.check_circle_rounded, color: c.success),
                          ],
                        ),
                      ),
              ),
              const Spacer(),
              AppButton(
                label: l.channelJoin,
                expand: true,
                onPressed: invite == null
                    ? null
                    : () async {
                        final pk = await context.read<ChannelStore>().join(
                          invite,
                        );
                        if (pk != null && context.mounted) {
                          context.pushReplacement('/channel/$pk');
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
