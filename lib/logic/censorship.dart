/// How Tor reaches the network, from plain to most disguised. The app climbs
/// this ladder on its own when a rung doesn't bootstrap in time.
enum TorLevel {
  /// Plain Tor: hides the IP and the relays, but Tor itself is visible.
  tor,

  /// obfs4 bridges: traffic looks like random bytes. Beats Tor blocking.
  obfs4,

  /// Snowflake: looks like a WebRTC video call through volunteer proxies,
  /// reached through a CDN. Beats bridge IP blocking.
  //
  // meek is not offered: Tor Browser's built-in meek line has no bridge
  // fingerprint, which Arti requires.
  snowflake;

  bool get disguised => this != tor;

  /// Name of the pluggable transport, as bridge lines and IPtProxy call it.
  String? get transport => switch (this) {
    tor => null,
    obfs4 => 'obfs4',
    snowflake => 'snowflake',
  };

  /// Bootstrap budget before trying the next rung. PTs need longer: the
  /// Snowflake rendezvous is slow.
  Duration get timeout => switch (this) {
    tor => const Duration(seconds: 90),
    obfs4 => const Duration(seconds: 90),
    snowflake => const Duration(seconds: 180),
  };

  List<String> get bridges => switch (this) {
    tor => const [],
    obfs4 => builtinObfs4,
    snowflake => builtinSnowflake,
  };
}

/// Order to try the rungs in. Starts where it last worked (censorship is
/// sticky), climbs, then tries the skipped lower rungs (the network may have
/// changed). With [disguise], plain Tor is never tried: somewhere using Tor
/// is itself dangerous, so its traffic must never be visible.
List<TorLevel> torLadder({TorLevel? lastGood, bool disguise = false}) {
  final floor = disguise ? TorLevel.obfs4 : TorLevel.tor;
  final start = lastGood == null || lastGood.index < floor.index
      ? floor
      : lastGood;
  final all = TorLevel.values.where((l) => l.index >= floor.index).toList();
  return [
    ...all.where((l) => l.index >= start.index),
    ...all.where((l) => l.index < start.index),
  ];
}

/// Snowflake client settings carried by its bridge line (broker URL,
/// domain fronts, ICE servers), for IPtProxy.
Map<String, String> snowflakeParams(String bridgeLine) {
  final out = <String, String>{};
  for (final part in bridgeLine.split(' ')) {
    final i = part.indexOf('=');
    if (i <= 0) continue;
    final key = part.substring(0, i);
    if (const {'url', 'fronts', 'ice', 'ampcache'}.contains(key)) {
      out[key] = part.substring(i + 1);
    }
  }
  return out;
}

// Built-in bridges, as shipped by Tor Browser (bridges.torproject.org
// moat/circumvention/builtin, fetched 2026-09-30). Public by design: they're
// meant to be hard to block, not secret.

const builtinObfs4 = [
  'obfs4 51.222.13.177:80 5EDAC3B810E12B01F6FD8050D2FD3E277B289A08 cert=2uplIpLQ0q9+0qMFrK5pkaYRDOe460LL9WHBvatgkuRr/SL31wBOEupaMMJ6koRE6Ld0ew iat-mode=0',
  'obfs4 212.83.43.95:443 BFE712113A72899AD685764B211FACD30FF52C31 cert=ayq0XzCwhpdysn5o0EyDUbmSOx3X/oTEbzDMvczHOdBJKlvIdHHLJGkZARtT4dcBFArPPg iat-mode=1',
  'obfs4 146.57.248.225:22 10A6CD36A537FCE513A322361547444B393989F0 cert=K1gDtDAIcUfeLqbstggjIw2rtgIKqdIhUlHp82XRqNSq/mtAjp1BIC9vHKJ2FAEpGssTPw iat-mode=0',
  'obfs4 209.148.46.65:443 74FAD13168806246602538555B5521A0383A1875 cert=ssH+9rP8dG2NLDN2XuFw63hIO/9MNNinLmxQDpVa+7kTOa9/m+tGWT1SmSYpQ9uTBGa6Hw iat-mode=0',
  'obfs4 45.145.95.6:27015 C5B7CD6946FF10C5B3E89691A7D3F2C122D2117C cert=TD7PbUO0/0k6xYHMPW3vJxICfkMZNdkRrb63Zhl5j9dW3iRGiCx0A7mPhe5T2EDzQ35+Zw iat-mode=0',
  'obfs4 37.218.245.14:38224 D9A82D2F9C2F65A18407B1D2B764F130847F8B5D cert=bjRaMrr1BRiAW8IE9U5z27fQaYgOhX1UCmOpg2pFpoMvo6ZgQMzLsaTzzQNTlm7hNcb+Sg iat-mode=0',
  'obfs4 212.83.43.74:443 39562501228A4D5E27FCA4C0C81A01EE23AE3EE4 cert=PBwr+S8JTVZo6MPdHnkTwXJPILWADLqfMGoVvhZClMq/Urndyd42BwX9YFJHZnBB3H0XCw iat-mode=1',
];

const builtinSnowflake = [
  'snowflake 192.0.2.4:80 8838024498816A039FCBBAB14E6F40A0843051FA fingerprint=8838024498816A039FCBBAB14E6F40A0843051FA url=https://1098762253.rsc.cdn77.org/ fronts=app.datapacket.com,www.datapacket.com ice=stun:stun.epygi.com:3478,stun:stun.uls.co.za:3478,stun:stun.voipgate.com:3478,stun:stun.mixvoip.com:3478,stun:stun.telnyx.com:3478,stun:stun.hot-chilli.net:3478,stun:stun.fitauto.ru:3478,stun:stun.m-online.net:3478 utls-imitate=hellorandomizedalpn',
  'snowflake 192.0.2.3:80 2B280B23E1107BB62ABFC40DDCC8824814F80A72 fingerprint=2B280B23E1107BB62ABFC40DDCC8824814F80A72 url=https://1098762253.rsc.cdn77.org/ fronts=app.datapacket.com,www.datapacket.com ice=stun:stun.epygi.com:3478,stun:stun.uls.co.za:3478,stun:stun.voipgate.com:3478,stun:stun.mixvoip.com:3478,stun:stun.telnyx.com:3478,stun:stun.hot-chilli.net:3478,stun:stun.fitauto.ru:3478,stun:stun.m-online.net:3478 utls-imitate=hellorandomizedalpn',
];
