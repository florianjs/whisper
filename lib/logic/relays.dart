import 'dart:math';

/// Relays used until the user edits the list. Chosen for NIP-17 gift-wrap
/// support; none is a directory or profile aggregator, so joining doesn't
/// announce the account anywhere it doesn't need to be.
///
/// Checked 2026-10-01: each accepts a gift wrap from an unknown sender and
/// serves it back. Spread over several countries so that no single
/// jurisdiction or operator can take messaging down.
///
/// The two onion services keep working when every relay *domain* is blocked
/// (they're only reachable through Tor, which is on by default).
const defaultRelays = [
  'wss://relay.damus.io', // US
  'wss://nos.lol', // DE
  'wss://relay.primal.net', // US
  'wss://relay.snort.social', // IE
  'wss://nostr.21crypto.ch', // CH
  'wss://relay.nostr.wirednet.jp', // JP
  'wss://nostr.stakey.net', // NL
  // nostr.oxtr.dev (DE)
  'ws://oxtrdevav64z64yb7x6rjg4ntzqjhedm5b5zjqulugknhzr46ny2qbad.onion',
  'ws://gnostr2jnapk72mnagq3cuykfon73temzp77hcbncn4silgt77boruid.onion',
];

/// Standby relays: never connected while the main list works (no extra Tor
/// circuits, battery or operators seeing our traffic). One takes the place
/// of a relay of the list that stayed dead for [deadRelayAfter].
///
/// Checked 2026-10-01 like [defaultRelays]: each accepts a gift wrap from an
/// unknown sender; all but relay.nostr.net serve it back without auth
/// (relay.nostr.net only hands gift wraps to their authenticated recipient).
/// Different hosts from each other and from the main list.
const spareRelays = [
  'wss://nostr.mom', // Hetzner
  'wss://offchain.pub', // US
  'wss://relay.angor.io', // Contabo
  'wss://nostr-pub.wellorder.net', // Hetzner US
  'wss://relay.nostr.net', // Cloudflare
];

/// How long a relay must stay unreachable — counted only while another relay
/// of the list was up, so a phone offline overnight kills nothing — before a
/// spare replaces it.
const deadRelayAfter = Duration(hours: 6);

/// Adds [elapsed] of downtime to each relay that is down while at least one
/// other is up. A connected relay starts over from zero. With no relay up we
/// are the ones offline: nothing is learnt about the relays.
Map<String, Duration> accrueDowntime(
  Map<String, Duration> downtime,
  Map<String, bool> relays,
  Duration elapsed,
) {
  if (!relays.values.any((connected) => connected)) return downtime;
  return {
    for (final e in relays.entries)
      if (!e.value) e.key: (downtime[e.key] ?? Duration.zero) + elapsed,
  };
}

/// Swaps every relay dead for [after] for the next unused spare, in place.
/// Dead relays go to the back of the spares: they may come back one day.
/// Null when nothing can change (no dead relay, or no spare left).
({List<String> relays, List<String> spares})? failover({
  required List<String> relays,
  required List<String> spares,
  required Map<String, Duration> downtime,
  Duration after = deadRelayAfter,
}) {
  final available = [
    for (final s in spares)
      if (!relays.contains(s)) s,
  ];
  final dead = <String>[];
  final next = <String>[];
  for (final r in relays) {
    if ((downtime[r] ?? Duration.zero) >= after && available.isNotEmpty) {
      dead.add(r);
      next.add(available.removeAt(0));
    } else {
      next.add(r);
    }
  }
  if (dead.isEmpty) return null;
  return (relays: next, spares: [...available, ...dead]);
}

enum RelayHealth {
  /// No relay reachable yet since start or since the last reconnect attempt.
  connecting,

  /// At least one relay reachable: messages can flow.
  online,

  /// Tried and none reachable: waiting for the next retry.
  offline,
}

/// One relay is enough to send and receive, so health is "any", not "all".
RelayHealth healthOf(Map<String, bool> relays, {required bool settled}) {
  if (relays.values.any((connected) => connected)) return RelayHealth.online;
  return settled ? RelayHealth.offline : RelayHealth.connecting;
}

/// Exponential backoff for reconnects: 2s, 4s, 8s… capped at 60s, with ±20%
/// jitter so every phone behind a flaky network doesn't retry in lockstep.
Duration retryDelay(int attempt, {Random? random}) {
  final base = min(60, 2 * pow(2, min(attempt, 5)).toInt());
  final jitter = 0.8 + (random ?? Random()).nextDouble() * 0.4;
  return Duration(milliseconds: (base * 1000 * jitter).round());
}

/// Canonical relay URL, or null if not acceptable. `wss://`, or `ws://` for
/// onion services only: plain `ws://` to a clearnet host would expose who
/// talks to which relay, and when, to anyone on the network, while an onion
/// circuit is end-to-end encrypted and authenticated by its address.
String? normalizeRelayUrl(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null || uri.host.isEmpty) return null;
  final scheme = uri.scheme.toLowerCase();
  final host = uri.host.toLowerCase();
  final onion = host.endsWith('.onion');
  if (scheme != 'wss' && !(scheme == 'ws' && onion)) return null;
  final path = uri.path == '/' ? '' : uri.path;
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '$scheme://$host$port$path';
}

bool isOnionRelay(String url) =>
    Uri.tryParse(url)?.host.toLowerCase().endsWith('.onion') ?? false;

/// Short display name: host for clearnet relays, "abcdefgh….onion" for
/// onion services (56-char addresses wrap badly and mean nothing to users).
String relayLabel(String url) {
  final host = Uri.tryParse(url)?.host ?? url;
  if (host.endsWith('.onion') && host.length > 20) {
    return '${host.substring(0, 8)}….onion';
  }
  return host.isEmpty ? url : host;
}
