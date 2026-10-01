#!/usr/bin/env bash
# Builds, signs, verifies and publishes a release on GitHub.
#
#   scripts/release.sh            full release (tag + GitHub release)
#   scripts/release.sh --dry-run  everything except tagging and publishing
#
# The version comes from pubspec.yaml (`version: X.Y.Z+N`); bump it first.
# Signing happens here, on this machine: the key never goes to GitHub.
set -euo pipefail

cd "$(dirname "$0")/.."
dry_run=false
[[ "${1:-}" == "--dry-run" ]] && dry_run=true

fail() { echo "✗ $*" >&2; exit 1; }
step() { echo; echo "▸ $*"; }

# --- Preconditions --------------------------------------------------------
version_line=$(grep -E '^version: ' pubspec.yaml) || fail "no version in pubspec.yaml"
version=${version_line#version: }
name=${version%%+*}
build_number=${version#*+}
tag="v$name"

[[ -f android/key.properties ]] ||
  fail "no android/key.properties: run scripts/new-signing-key.sh first"
store=$(awk -F= '$1=="storeFile"{print $2}' android/key.properties)
alias=$(awk -F= '$1=="keyAlias"{print $2}' android/key.properties)
[[ -f "$store" ]] || fail "keystore not found: $store"

if ! $dry_run; then
  [[ -z "$(git status --porcelain)" ]] || fail "working tree not clean"
  [[ "$(git branch --show-current)" == "main" ]] || fail "not on main"
  git remote get-url origin >/dev/null 2>&1 || fail "no 'origin' remote"
  ! git rev-parse -q --verify "refs/tags/$tag" >/dev/null ||
    fail "tag $tag already exists: bump the version in pubspec.yaml"
  command -v gh >/dev/null || fail "gh CLI not installed"
fi
command -v xcodebuild >/dev/null || fail "Xcode not installed (iOS build)"

sdk=${ANDROID_HOME:-$(awk -F= '$1=="sdk.dir"{print $2}' android/local.properties 2>/dev/null)}
apksigner=$(ls -d "$sdk"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -1)
[[ -x "$apksigner" ]] || fail "apksigner not found in the Android SDK ($sdk)"
aapt2=$(ls -d "$sdk"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -1)
[[ -x "$aapt2" ]] || fail "aapt2 not found in the Android SDK ($sdk)"

# --- Passwords (memory only) ---------------------------------------------
read -rsp "Keystore password: " WHISPER_STORE_PASSWORD ||
  fail "no input: run this script in a terminal (it asks for a password)"
echo
export WHISPER_STORE_PASSWORD WHISPER_KEY_PASSWORD="$WHISPER_STORE_PASSWORD"
keytool -list -keystore "$store" -alias "$alias" \
  -storepass:env WHISPER_STORE_PASSWORD >/dev/null 2>&1 ||
  fail "wrong keystore password"
cert=$(keytool -J-Duser.language=en -list -v -keystore "$store" -alias "$alias" \
  -storepass:env WHISPER_STORE_PASSWORD 2>/dev/null |
  awk -F': ' '/SHA256:/ {print $2}')

# The published fingerprint pins the key: a release signed with any other key
# would make users' updates fail (or be a fake). First release creates it.
pin=release/signing-cert-sha256.txt
if [[ -f "$pin" ]]; then
  [[ "$(cat "$pin")" == "$cert" ]] ||
    fail "this key ($cert) is not the published one ($(cat "$pin"))"
else
  $dry_run || fail "no $pin: run a --dry-run first, then commit the file it creates"
  mkdir -p release
  echo "$cert" > "$pin"
  echo "Created $pin — review and commit it before the first release."
fi

# --- Checks ---------------------------------------------------------------
step "Analyze and test"
fvm flutter analyze
fvm flutter test

# --- Build ----------------------------------------------------------------
step "Build $tag"
fvm flutter build apk --release --split-per-abi
fvm flutter build apk --release

out=build/app/outputs/flutter-apk
dist=dist/$tag
rm -rf "$dist" && mkdir -p "$dist"
cp "$out/app-release.apk" "$dist/whisper-$tag.apk"
for abi in arm64-v8a armeabi-v7a x86_64; do
  cp "$out/app-$abi-release.apk" "$dist/whisper-$tag-$abi.apk"
done

# iPhone: unsigned IPA. SideStore / AltStore sign it with the user's own
# Apple ID; no Apple developer account, no App Store review.
step "Build iOS $tag"
fvm flutter build ios --release --no-codesign
payload=$(mktemp -d)
mkdir "$payload/Payload"
cp -R build/ios/iphoneos/Runner.app "$payload/Payload/"
ipa="$PWD/$dist/whisper-$tag.ipa"
(cd "$payload" && zip -qry "$ipa" Payload)
rm -rf "$payload"

# --- Verify ---------------------------------------------------------------
step "Verify signatures"
for apk in "$dist"/*.apk; do
  got=$("$apksigner" verify --print-certs "$apk" |
    awk -F': ' '/Signer #1 certificate SHA-256 digest/ {print $2}')
  want=$(echo "$cert" | tr -d ':' | tr '[:upper:]' '[:lower:]')
  [[ "$got" == "$want" ]] || fail "$apk is not signed with the release key"
  echo "✓ $(basename "$apk")"
done
# Debug builds get INTERNET from Flutter's debug manifest; a release without
# it has no network at all (v1.0.0 shipped like that). Permissions removed on
# purpose must not come back through a plugin either.
step "Verify permissions"
need=(INTERNET FOREGROUND_SERVICE POST_NOTIFICATIONS REQUEST_INSTALL_PACKAGES)
never=(RECORD_AUDIO READ_EXTERNAL_STORAGE WRITE_EXTERNAL_STORAGE)
for apk in "$dist"/*.apk; do
  perms=$("$aapt2" dump permissions "$apk")
  for p in "${need[@]}"; do
    grep -qx "uses-permission: name='android.permission.$p'" <<<"$perms" ||
      fail "$(basename "$apk") lacks android.permission.$p"
  done
  for p in "${never[@]}"; do
    ! grep -q "name='android.permission.$p'" <<<"$perms" ||
      fail "$(basename "$apk") requests android.permission.$p"
  done
  echo "✓ $(basename "$apk")"
done

(cd "$dist" && shasum -a 256 *.apk *.ipa > SHA256SUMS.txt)
cat "$dist/SHA256SUMS.txt"

# AltStore / SideStore source. Published as a release asset, so
# releases/latest/download/apps.json always describes the newest version.
TAG=$tag NAME=$name BUILD=$build_number IPA="$dist/whisper-$tag.ipa" \
  python3 - > "$dist/apps.json" <<'JSON'
import json, os, datetime
repo = "https://github.com/florianjs/whisper"
tag = os.environ["TAG"]
print(json.dumps({
    "name": "Whisper",
    "identifier": "app.whisper.messenger.source",
    "sourceURL": f"{repo}/releases/latest/download/apps.json",
    "iconURL": "https://raw.githubusercontent.com/florianjs/whisper/main/assets/logo.png",
    "tintColor": "#8E7DFF",
    "apps": [{
        "name": "Whisper",
        "bundleIdentifier": "app.whisper.messenger",
        "developerName": "Whisper",
        "subtitle": "Private messenger. No phone number. Over Tor.",
        "localizedDescription": "End-to-end encrypted messenger with no phone number, "
            "no account server, Nostr relays over Tor, a panic button and a duress PIN.",
        "iconURL": "https://raw.githubusercontent.com/florianjs/whisper/main/assets/logo.png",
        "tintColor": "#8E7DFF",
        "versions": [{
            "version": os.environ["NAME"],
            "buildVersion": os.environ["BUILD"],
            "date": datetime.date.today().isoformat(),
            "localizedDescription": f"Whisper {tag}: {repo}/releases/tag/{tag}",
            "downloadURL": f"{repo}/releases/download/{tag}/whisper-{tag}.ipa",
            "size": os.path.getsize(os.environ["IPA"]),
            "minOSVersion": "15.0",
        }],
        "appPermissions": {"entitlements": [], "privacy": {
            "NSCameraUsageDescription": "Scan QR codes, take photos to send.",
            "NSPhotoLibraryUsageDescription": "Choose photos to send.",
            "NSFaceIDUsageDescription": "Unlock Whisper with Face ID.",
        }},
    }],
    "news": [],
}, indent=2))
JSON

if $dry_run; then
  echo; echo "Dry run done: $dist (not tagged, not published)."
  exit 0
fi

# --- Publish --------------------------------------------------------------
step "Publish $tag"
notes=$(mktemp)
cat > "$notes" <<NOTES
## Install

Download **whisper-$tag-arm64-v8a.apk** (nearly every phone from the last ten
years; \`armeabi-v7a\` for older ones). If unsure, **whisper-$tag.apk** works
everywhere but is about three times bigger. Open it, and allow installing from
this source when Android asks.

**iPhone:** add this source in [SideStore](https://sidestore.io) (or AltStore),
then install Whisper from it:
\`https://github.com/florianjs/whisper/releases/latest/download/apps.json\`

## Verify

- SHA-256 of each file (APKs and IPA): \`SHA256SUMS.txt\`
- Signing certificate SHA-256 (the same for every release, see
  \`release/signing-cert-sha256.txt\` in the repository):

  \`$cert\`

  Check with \`apksigner verify --print-certs whisper-$tag.apk\`, or compare
  with what AppVerifier / Obtainium shows.
NOTES
git tag -a "$tag" -m "Whisper $tag"
git push origin "$tag"
gh release create "$tag" "$dist"/*.apk "$dist"/*.ipa "$dist/apps.json" \
  "$dist/SHA256SUMS.txt" \
  --title "Whisper $tag" --notes-file "$notes"
rm -f "$notes"
echo; echo "Released $tag."
