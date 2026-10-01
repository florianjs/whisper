import 'dart:math';

/// In-app updates from the project's GitHub releases. Pure rules; the
/// network, files and installer live in UpdateService and the platform.

/// Where releases are published.
const updateRepo = 'florianjs/whisper';

/// SHA-256 of the release signing certificate, as published in
/// `release/signing-cert-sha256.txt` (a test keeps both in sync). Android
/// already refuses an update signed with another key; checking first gives
/// a clear error instead of a failed install, and refuses a lookalike app.
const releaseCertSha256 =
    'ec1d9254bffa601cc07db530682b3ef351b5414511bbba61e211d17aae62026f';

/// Upper bound for a download: the universal APK is ~220 MB.
const maxUpdateBytes = 400 * 1024 * 1024;

/// ABIs with their own APK, best first (see scripts/release.sh).
const releaseAbis = ['arm64-v8a', 'armeabi-v7a', 'x86_64'];

/// `1.2.3` from `v1.2.3`, `1.2.3` or `1.2.3+45` (build number ignored).
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  static final _pattern = RegExp(
    r'^v?(\d{1,4})\.(\d{1,4})\.(\d{1,4})(\+\d+)?$',
  );

  static AppVersion? parse(String input) {
    final m = _pattern.firstMatch(input.trim());
    if (m == null) return null;
    return AppVersion(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  String get tag => 'v$this';

  @override
  String toString() => '$major.$minor.$patch';
}

/// Redirects to `…/releases/tag/<tag>` — no API call, so no rate limit on
/// shared Tor exits.
Uri latestReleaseUri([String repo = updateRepo]) =>
    Uri.https('github.com', '/$repo/releases/latest');

/// Version from the `releases/latest` redirect; null when there is no
/// release yet (GitHub then redirects to the release list) or the answer
/// isn't one of ours.
AppVersion? versionFromRedirect(Uri location, [String repo = updateRepo]) {
  if (location.host != 'github.com') return null;
  final segments = location.pathSegments;
  final parts = repo.split('/');
  if (segments.length != 5 ||
      segments[0] != parts[0] ||
      segments[1] != parts[1] ||
      segments[2] != 'releases' ||
      segments[3] != 'tag') {
    return null;
  }
  return AppVersion.parse(segments[4]);
}

/// The APK for this phone: the first ABI it supports that has its own
/// build, else the universal one.
String apkName(AppVersion version, List<String> supportedAbis) {
  final abi = supportedAbis.where(releaseAbis.contains).firstOrNull;
  return abi == null
      ? 'whisper-${version.tag}.apk'
      : 'whisper-${version.tag}-$abi.apk';
}

Uri assetUri(AppVersion version, String name, [String repo = updateRepo]) =>
    Uri.https('github.com', '/$repo/releases/download/${version.tag}/$name');

/// `shasum -a 256` output → file name → lowercase hex digest.
Map<String, String> parseSums(String text) {
  final line = RegExp(r'^([0-9a-fA-F]{64}) [ *]?(\S+)$');
  return {
    for (final l in text.split('\n'))
      if (line.firstMatch(l.trim()) case final m?) m[2]!: m[1]!.toLowerCase(),
  };
}

/// About once a day, at a random time: regular checks at a fixed hour would
/// mark the phone on the network.
Duration nextCheckIn(Random random) =>
    Duration(hours: 20) + Duration(minutes: random.nextInt(8 * 60));

/// Installed by a store (Play, F-Droid, Obtainium…): updates come from it,
/// and installing over it would fail or fight it. On iPhone ("ios") they
/// always do: SideStore / AltStore update from the release source.
bool installedByStore(String? installer) =>
    installer != null &&
    const {
      'ios',
      'com.android.vending',
      'org.fdroid.fdroid',
      'org.fdroid.basic',
      'com.aurora.store',
      'dev.imranr.obtainium',
      'dev.imranr.obtainium.fdroid',
    }.contains(installer);
