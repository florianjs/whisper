# Whisper — threat model

Status: 2026-09-30, Android build. What Whisper protects, against whom, and where it stops.

## Goals

1. **Content confidentiality** — only the intended people read messages, photos, group and channel posts.
2. **Anonymity** — no phone number, e-mail or real name; nothing links an account to a person.
3. **Metadata minimisation** — relays learn as little as possible about who talks to whom, when.
4. **Censorship resistance** — messages get through where relays, Tor, or both are blocked.
5. **Device seizure** — a phone taken, unlocked or not, reveals as little as possible, and can be wiped fast.

## Assets

| Asset | Where | Protection |
|---|---|---|
| Identity key (secp256k1) | Android Keystore (AES-GCM wrapped), optionally sealed under Argon2id(PIN) | Never leaves the phone; recovery phrase **never stored**, shown once at creation |
| Messages, contacts, groups, channels | SQLCipher DB, raw 256-bit key in Keystore | Crypto-shredded by deleting the key |
| Channel keys | Derived from the identity key (HMAC) | Recovered with the identity; nothing extra to store |
| Network history (Tor guards, bridge in use) | App-private files | Erased on panic |
| History backups (optional) | File the user saves anywhere | AES-256-GCM, key derived from the identity: useless without the recovery phrase; neutral file name |

## Adversaries and what they get

### Relay operators (Nostr relays)
- **See:** gift wraps (kind 1059) addressed to a pubkey, signed by throwaway keys, timestamps jittered
  up to 2 days; our inbox-relay list (kind 10050); channel events (encrypted); a Tor exit IP.
- **Don't see:** content, sender, group membership (a group message is N separate gift wraps),
  channel names or posts (AES-GCM with a key only invitees hold), which post a reaction targets.
- **Linkability:** the inbox subscription reveals the recipient pubkey (inherent to Nostr). Channel
  subscriptions use a **separate connection and Tor circuit**, so a relay can't tie "pubkey X"
  to "follows channel Y" by connection. Timing correlation between the two remains possible.
- **Can:** drop or delay messages (mitigated by several relays incl. 2 onion services, and by spare relays
  that replace a relay dead for 6 h — only on the default list; the new list is republished as
  kind 10050 and senders re-look it up when delivery fails), refuse
  service, keep copies (a panic sends a NIP-62 "vanish" request; compliance is up to the relay).

### Network observer (ISP, state, Wi-Fi owner)
- Tor on by default, fail-closed: no connection leaves the phone directly while Tor is starting.
- **Plain Tor:** sees Tor use, not Whisper use or destinations.
- **Disguised (obfs4 / Snowflake):** sees random-looking TCP to a bridge, or a CDN + WebRTC —
  verified on device: no Tor relay or Nostr relay IP appears.
- **Ladder:** escalates automatically; with "Disguise my connection" plain Tor is never attempted.

### Contacts and strangers
- Strangers land in **Requests**: no profile photo, no read of our card until accepted; can be blocked.
- Group / channel invites from non-accepted people are held or dropped.
- Profile photos and chat images are re-encoded, EXIF/GPS stripped, size-capped.
- Nicknames: shown only for accepted contacts, stripped of invisible and text-direction
  characters, capped at 32 characters; a local name I give a contact wins; the chat header always
  shows the key-derived username next to any other name, so nobody can pass for another contact.
- Safety numbers (60 digits) let two people verify keys out of band.

### Someone holding the phone
- **Locked app:** PIN (Argon2id, lockout) or biometrics; identity and DB key sealed while locked.
- **Duress PIN:** looks like a normal unlock, silently erases everything.
- **Panic button** (hold 1.5 s): DB key → vanish request (≤ 3 s) → identity → DB file → clipboard →
  Tor/PT files → preferences. Each step independent; key first so an interrupted wipe still leaves
  unreadable data.
- **Screen:** FLAG_SECURE (no screenshots, blank in app switcher), history blur, masked input.
- **Spyware / screen readers:** in-app keyboard (no IME ever attached), accessibility services listed
  and content hidden from them on demand, sensitive clipboard auto-cleared.

### Update channel (GitHub Releases)
- **Sees:** a Tor exit asking for the latest Whisper release, about once a day at a random time
  (opt-out), then downloading one APK.
- **Can't push a fake update:** the APK must match `SHA256SUMS.txt`, be signed with the pinned
  release certificate (checked by the app, then by Android itself), and carry a higher version
  (no downgrade to a vulnerable build). The signing key never leaves the maintainer's machine.
- **Can:** withhold updates. A compromised GitHub account alone can't sign an update.

## Out of scope / known limits

- **Compromised OS or root malware** can read the screen and memory. Paranoia mode reduces, not removes, exposure.
- **Global passive adversary** correlating Tor traffic timing.
- **Group admin trust:** the admin decides membership; a malicious member can leak content.
- **Channel invites carry the read key:** anyone holding one can read and forward. No revocation yet (key rotation planned).
- **Reaction counts** can be inflated by one person with several identities.
- **Relays deleting data** after a vanish request is voluntary.
- **Background delivery** without Google: a foreground service keeps the process, Tor and the
  relay connections alive (permanent low-priority notification). "New message" notifications
  carry a count only — never a name or text. A locked app can't decrypt: it keeps only its
  public key (memory, never disk) and an anonymous subscription for gift wraps addressed to it,
  enough to say "New message" with no count. The relays, which see that key on every gift wrap
  anyway, learn that the client is online while locked.
- **Distribution:** the APK itself may be blocked; F-Droid / direct download / checksum publication planned.
- **Licence:** obfs4 (Lyrebird) is GPL-3; distribution requires a GPL-compatible app licence.

## Verified on device (emulator)

Encrypted DB unreadable without key · panic erases and stays logged out · FLAG_SECURE · paranoia
keyboard never shows the IME · Tor: no direct TCP to relays · obfs4 and Snowflake: only bridge / CDN
visible · onion relays reachable · channel traffic on its own connections · message received and
notified with the activity destroyed · auto-lock and FLAG_SECURE hold when a new activity attaches
to the long-lived engine.

Not yet verified on a real device: biometrics, camera QR scan, Keystore failure path.
