<p align="center">
  <img src="assets/logo.png" width="160" alt="Whisper logo">
</p>

<h1 align="center">Whisper</h1>

**Anonymous, end-to-end encrypted messenger.** No phone number, no e-mail, no account server.
Your identity is a key pair that lives on your phone; your messages travel over
[Nostr](https://nostr.com) relays, through Tor, by default.

**An alternative to Telegram, WhatsApp and Signal** for people who need more than encryption:

- **No phone number**: all three require one to sign up, which ties the account to a SIM card,
  and often to an identity document.
- **No central server**: no company holds the account list or the social graph, or can be
  ordered to block the service. Messages go through independent relays, and any relay can be
  replaced.
- **Built for censorship and seizure**: Tor on by default, disguised connections, a panic wipe
  and a duress PIN.

> **Status:** working MVP, Android and iPhone. Not audited. Don't rely on it yet where
> your safety depends on it. See [Limits](#known-limits).

---

## Install (Android)

1. Open the [latest release](../../releases/latest).
2. Download **`whisper-vX.Y.Z-arm64-v8a.apk`**, which fits nearly every phone from the
   last ten years. For an older phone, take `armeabi-v7a`. If unsure, `whisper-vX.Y.Z.apk`
   works everywhere, but it is about three times bigger: it bundles Tor for every processor
   type.
3. Open the file and allow installing from this source when Android asks.

**Verify what you install.** Every release lists the SHA-256 of each file in
`SHA256SUMS.txt`. Every APK is signed with the same key, whose certificate SHA-256 is published
in [`release/signing-cert-sha256.txt`](release/signing-cert-sha256.txt) and in each release's
notes. Android only installs an update signed with the key of the installed version, so a
tampered build can't replace yours. Check a download with
`apksigner verify --print-certs whisper-vX.Y.Z.apk`, or let
[Obtainium](https://github.com/ImranR98/Obtainium) / AppVerifier do it and keep you up to date.

## Install (iPhone)

Whisper isn't on the App Store: its rules don't fit an app built for anonymity and censorship
resistance. Install it with [SideStore](https://sidestore.io), which signs apps with your own
Apple ID (free):

1. Install SideStore by following [its guide](https://docs.sidestore.io). It needs a computer
   once.
2. In SideStore, open **Sources**, tap **+**, and add:
   `https://github.com/florianjs/whisper/releases/latest/download/apps.json`
3. Install **Whisper** from that source. SideStore notifies you of new versions.

A free Apple ID signs apps for 7 days: SideStore refreshes Whisper in the background, so open
SideStore now and then. AltStore works the same way.

On iPhone, messages arrive while Whisper is open: iOS doesn't let apps keep a private connection
in the background. Relays keep messages for at least two days.

---

## Features

### Messaging

- **1:1 chats** — end-to-end encrypted (NIP-17: NIP-44 encryption inside NIP-59 gift wraps).
  Relays see neither the sender nor the content.
- **Private groups** — up to 20 members; each message is sent as one separate gift wrap per
  member, so relays can't even tell a group exists.
- **Broadcast channels** — one admin posts, invitees read and react. Name, posts and reactions
  are encrypted with a key only invitees hold. Public or private, invite by QR code or link.
- **Photos** — re-encoded, metadata (EXIF / GPS) stripped, size-capped, then sent in encrypted
  chunks over the same relays. No file server.
- **Profile photo and nickname** — only shared with contacts you accepted.
- **Message requests** — strangers land in a separate inbox; nothing is shown to them (photo,
  read state) until you accept. Block anytime.
- **Safety numbers** — 60 digits to verify a contact's key in person.
- **Contact QR codes** — carry your inbox relays, so a new contact reaches you right away.

### Identity

- **No sign-up.** A 24-word recovery phrase (BIP39) derives your key (NIP-06).
- **The phrase is shown once and never stored.** You prove you saved it before going on.
- **Username derived from the key** (`swift-otter-4821`): nobody chose it, nothing ties it to you.
  It survives a restore.
- **Optional nickname**, shared like the profile photo: encrypted, and only with contacts you
  accepted. Rename any contact on your phone; your name for them always wins.
- **Restore** on any phone with the 24 words. That restores the identity, not the history,
  which stays local. Use the backup for the history.
- **Encrypted history backup** — a file you save anywhere, readable only with your recovery
  phrase.

### Experience

- Modern interface, **light and dark themes** (follows the system, or forced in settings).
- Search, and filters for chats, groups and channels.
- English, French, Spanish, German, Russian and Simplified Chinese.
- Background delivery without Google services, with notifications that never show a name or
  text.
- **In-app updates**: about once a day, Whisper looks for a new release through Tor. It
  downloads the APK for your phone and checks it before installing: checksum, same signing
  key, newer version. Android asks you to confirm the first update; after that, Android 12+
  can update silently. You can turn this off; store installs (F-Droid, Obtainium) update
  through their store.

---

## Security layers

Whisper stacks independent protections. Each layer assumes the one before it may fail.

### 1. Content: end-to-end encryption

| What | How |
|---|---|
| Direct and group messages | NIP-44 (ChaCha20 + HMAC-SHA256), wrapped twice (NIP-59 seal + gift wrap) |
| Sender | Hidden: each gift wrap is signed by a throwaway key |
| Timestamps | Randomised up to 2 days back, to blur timing |
| Channels | AES-GCM with a key derived from the admin identity, shared only through invites |
| Images | Same gift wraps as messages, in chunks |

### 2. Metadata: what relays learn

- **Relays see:** an encrypted blob addressed to a pubkey, signed by a random key, at a fuzzy
  time, coming from a Tor exit.
- **Relays don't see:** content, sender, group membership, channel names or posts, or which post
  a reaction targets.
- **Channel subscriptions use their own connection and Tor circuit**, so a relay can't tie
  "this pubkey" to "follows this channel" through the connection.

### 3. Network: Tor by default, fail-closed

- **Every connection goes through Tor** (embedded [Arti](https://gitlab.torproject.org/tpo/core/arti)),
  library traffic included.
- **Fail-closed:** while Tor is starting, nothing leaves the phone directly.
- **Relays spread across countries and operators**, including **2 onion services** that still
  work when every relay domain is blocked.
- **Spare relays:** standby relays, never connected normally. They replace a relay that stayed
  dead for 6 h while others worked. The new list is republished so contacts follow.

### 4. Censorship circumvention: an automatic ladder

The app climbs on its own, and only as far as needed. It remembers what worked.

| Rung | Looks like | Beats |
|---|---|---|
| Tor | Tor traffic | Relay IP / DNS blocking, hides your IP |
| Tor + obfs4 bridges | Random bytes | Tor blocking (DPI) |
| Tor + Snowflake | A WebRTC video call through a CDN | Bridge IP blocking |

With **"Disguise my connection"**, plain Tor is never tried: for places where using Tor is itself
dangerous. The interface says "Protected" or "Disguised", never jargon.

### 5. Device at rest

| Secret | Protection |
|---|---|
| Identity key | Android Keystore (AES-GCM wrapped), optionally sealed under Argon2id(PIN) |
| Messages, contacts, groups, channels | SQLCipher database, random 256-bit key in the Keystore |
| Recovery phrase | **Never stored** |
| Network state (Tor guards, bridges) | App-private files, erased on panic |

### 6. Someone holding the phone

- **App lock:** PIN (Argon2id, escalating lockout) or biometrics, with auto-lock. While locked,
  the keys are sealed and the database is closed.
- **Duress PIN:** looks like a normal unlock and silently erases everything.
- **Panic button:** hold for 1.5 s. It erases the database key first, so even an interrupted
  wipe leaves only unreadable data. Then it sends a NIP-62 "vanish" request to the relays, and
  erases the identity, the database file, the clipboard, the Tor files and the preferences.
- **Screen protection:** no screenshots and a blank app-switcher preview on sensitive screens
  (or everywhere).

### 7. Paranoia mode (against spyware)

Each toggle defends against a specific threat; one switch turns them all on.

- **In-app keyboard:** the system keyboard never sees what you type.
- **Shuffled keys:** against malware logging touch positions.
- **Masked input:** `•` instead of the typed characters.
- **Blurred history:** messages and list previews stay hidden until long-pressed.
- **Hidden from accessibility services:** the usual way spyware reads other apps. This breaks
  screen readers, hence opt-in.
- **Block screenshots everywhere.**
- Sensitive clipboard content (the recovery phrase) is cleared after 60 s.

Full analysis, with adversaries, assets and verified behaviour: **[docs/THREAT_MODEL.md](docs/THREAT_MODEL.md)**.

---

## Known limits

- **A compromised OS or root malware** can read the screen and memory. Paranoia mode reduces
  the exposure; it doesn't remove it.
- **A global passive adversary** correlating Tor traffic timing is out of scope.
- **The inbox subscription reveals your pubkey to your relays.** That's inherent to Nostr.
- **Group admins** decide membership; any member can leak content.
- **A channel invite carries the read key.** No revocation yet.
- **Reaction counts** can be inflated by one person with several identities.
- **Relays honouring a "vanish" request** is voluntary.
- **Background delivery** needs a foreground service and its permanent notification.

---

## Architecture

| Layer | Choice |
|---|---|
| App | Flutter (stable, pinned with [fvm](https://fvm.app)), `provider` + `ChangeNotifier`, `go_router` |
| Nostr | [`ndk`](https://pub.dev/packages/ndk) behind a `Transport` interface |
| Crypto | NIP-06 / BIP340 keys, NIP-44, NIP-59, AES-GCM, Argon2id |
| Storage | SQLCipher (`sqflite_sqlcipher`), `flutter_secure_storage` (Keystore / Keychain) |
| Tor | Arti via the vendored `packages/tor` plugin (Rust, built with cargokit) |
| Pluggable transports | IPtProxy (Lyrebird obfs4, Snowflake) |

```
lib/
├── logic/     Pure, testable rules: crypto, protocols, relays, censorship ladder, backups
├── data/      Stores and services: identity, messages, groups, channels, relays, Tor, vault
├── models/    Plain data types
├── screens/   One file per screen
├── widgets/   Reusable UI components (ui.dart holds the design primitives)
├── theme/     Design tokens (light / dark palettes) and the Material theme
└── l10n/      Strings in English, French, Spanish, German, Russian and Chinese (ARB)
packages/tor/  Vendored Tor (Arti) plugin
docs/          Threat model
test/          Unit and widget tests
```

---

## Build and run

**Requirements**

- [fvm](https://fvm.app). The Flutter version is pinned in `.fvmrc`.
- Rust via [rustup](https://rustup.rs) (not Homebrew), and `cargo install cargo-ndk`.
- The Android SDK and NDK.

```sh
fvm install
fvm flutter pub get
fvm flutter run            # first build compiles Tor (~5 min)
```

**Checks** (also run by CI on every push)

```sh
fvm flutter analyze
fvm flutter test
```

**Releasing** (maintainers): signing happens on the maintainer's machine; the key never
goes to GitHub.

```sh
scripts/new-signing-key.sh     # once, ever: back up the key and its password
# bump `version:` in pubspec.yaml, commit
scripts/release.sh --dry-run   # build, sign, verify, checksums into dist/
scripts/release.sh             # same, then tag and publish the GitHub release
```

---

## Roadmap

- [ ] Hardening pass (in progress)
- [ ] More censorship rungs: WebTunnel, DNSTT
- [ ] Peer-to-peer over onion services
- [ ] Local mesh for full internet shutdowns
- [ ] Channel key rotation (invite revocation)
- [x] iOS, through SideStore / AltStore
- [x] Signed APKs with published checksums on GitHub Releases
- [ ] F-Droid

---

## License

[GPL-3.0](LICENSE). Bundled components keep their own licences (the Tor plugin in
`packages/tor` is MIT, obfs4 / Lyrebird is GPL-3).
