import 'channel.dart';
import 'contact_code.dart';

/// Something in a message that opens a place in the app: a person, a
/// channel invite, a group. Never a web link: nothing here leaves the app.
sealed class InAppLink {
  const InAppLink(this.start, this.end);

  /// Range in the message text.
  final int start;
  final int end;
}

/// `npub…`, `nprofile…`, with or without `nostr:`.
class ContactLink extends InAppLink {
  const ContactLink(super.start, super.end, this.contact);
  final ContactCode contact;
}

/// `whisper-channel:…`: carries the read key, like the QR code.
class ChannelLink extends InAppLink {
  const ChannelLink(super.start, super.end, this.invite);
  final ChannelInvite invite;
}

/// `whisper-group:…`: only opens the group for its members.
class GroupLink extends InAppLink {
  const GroupLink(super.start, super.end, this.groupId);
  final String groupId;

  static const prefix = 'whisper-group:';
  static String encode(String groupId) => '$prefix$groupId';
}

final _links = RegExp(
  r'whisper-channel:[A-Za-z0-9_-]+'
  r'|whisper-group:[0-9a-f]{32}(?![0-9a-zA-Z])'
  // bech32 data charset; the parser checks the checksum.
  r'|(?:nostr:)?(?:npub1|nprofile1)[02-9ac-hj-np-z]+',
  caseSensitive: false,
);

/// Valid links in [text], in order. Anything that looks like one but
/// doesn't parse (typo, truncated paste) stays plain text.
List<InAppLink> findLinks(String text) {
  final found = <InAppLink>[];
  for (final m in _links.allMatches(text)) {
    // Glued to a word: part of something else.
    if (m.start > 0 && RegExp(r'[0-9A-Za-z]').hasMatch(text[m.start - 1])) {
      continue;
    }
    final s = m[0]!;
    final lower = s.toLowerCase();
    final InAppLink? link;
    if (lower.startsWith('whisper-channel:')) {
      final invite = ChannelInvite.parse(s);
      link = invite == null ? null : ChannelLink(m.start, m.end, invite);
    } else if (lower.startsWith(GroupLink.prefix)) {
      link = GroupLink(
        m.start,
        m.end,
        lower.substring(GroupLink.prefix.length),
      );
    } else {
      final contact = parseContactCode(s);
      link = contact == null ? null : ContactLink(m.start, m.end, contact);
    }
    if (link != null) found.add(link);
  }
  return found;
}
