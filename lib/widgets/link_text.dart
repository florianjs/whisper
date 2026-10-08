import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/channel_store.dart';
import '../data/group_store.dart';
import '../data/identity_store.dart';
import '../data/relay_service.dart';
import '../l10n/app_localizations.dart';
import '../logic/links.dart';

/// Message text where contacts, channel invites and group links open in the
/// app on tap. Plain [Text] when there are none.
class LinkText extends StatefulWidget {
  const LinkText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<LinkText> {
  late List<InAppLink> _links;
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(LinkText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _parse();
  }

  void _parse() {
    _disposeRecognizers();
    _links = findLinks(widget.text);
    for (final link in _links) {
      _recognizers.add(
        TapGestureRecognizer()..onTap = () => openInAppLink(context, link),
      );
    }
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_links.isEmpty) return Text(widget.text, style: widget.style);
    final text = widget.text;
    final linkStyle = TextStyle(
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: widget.style?.color,
    );
    final spans = <TextSpan>[];
    var at = 0;
    for (final (i, link) in _links.indexed) {
      if (link.start > at) {
        spans.add(TextSpan(text: text.substring(at, link.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(link.start, link.end),
          style: linkStyle,
          recognizer: _recognizers[i],
        ),
      );
      at = link.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}

/// Opens what [link] points to. A channel invite goes through the follow
/// screen: tapping a message never follows anything by itself.
void openInAppLink(BuildContext context, InAppLink link) {
  final l = AppLocalizations.of(context);
  switch (link) {
    case ContactLink(:final contact):
      final me = context.read<IdentityStore>().identity?.publicKey;
      if (contact.pubkey == me) return;
      context.read<RelayService>().rememberInboxRelays(
        contact.pubkey,
        contact.relays,
      );
      context.push('/chat/${contact.pubkey}');
    case ChannelLink(:final invite):
      final known = context.read<ChannelStore>().channel(invite.channelPk);
      if (known != null) {
        context.push('/channel/${invite.channelPk}');
      } else {
        context.push('/channel/join', extra: invite.encode());
      }
    case GroupLink(:final groupId):
      if (context.read<GroupStore>().group(groupId) != null) {
        context.push('/group/$groupId');
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.groupLinkNotMember)));
      }
  }
}
