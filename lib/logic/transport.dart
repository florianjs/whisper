import 'package:ndk/ndk.dart' show Nip01Event;

/// Anything that can carry NIP-59 gift wraps: Nostr relays today; Tor, onion
/// P2P and local mesh later (tasks 12–14). Gift wraps are self-contained and
/// identified by their id, so several transports can run side by side and
/// receivers dedupe.
abstract class Transport {
  /// Gift wraps addressed to us, including our own self-copies.
  Stream<Nip01Event> get incoming;

  /// Delivers [giftWrap] to the pubkey in its `p` tag. Throws if no route
  /// accepted it, so the caller can mark the message failed and retry.
  Future<void> deliver(Nip01Event giftWrap);
}

/// Pub/sub for broadcast channels: plain signed (content-encrypted) events,
/// unlike gift wraps.
abstract class ChannelTransport {
  /// Posts, metadata and reactions of the watched channels.
  Stream<Nip01Event> get channelEvents;

  /// Replaces the watched set. [relays]: extra relays the channels live on
  /// (from their invites), on top of ours. Kept alive across reconnects.
  /// [probes]: keys that may own a channel (restore): metadata only.
  void watchChannels(
    Set<String> channelPks, {
    List<String> relays = const [],
    Set<String> probes = const {},
  });

  /// Throws if no relay accepted it.
  Future<void> publishChannelEvent(
    Nip01Event event, {
    List<String> relays = const [],
  });
}
