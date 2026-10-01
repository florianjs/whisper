#!/usr/bin/env bash
# Creates Whisper's release signing key — once, ever.
#
# Every update must be signed with this same key, or Android refuses to
# install it over the previous version. Back up the keystore file AND its
# password (password manager + offline copy): losing either means users can
# never be updated again; leaking them lets anyone ship a fake update.
#
# The key lives outside the repo; android/key.properties (gitignored) points
# to it. Passwords are never written to disk.
set -euo pipefail

cd "$(dirname "$0")/.."
dir="${WHISPER_SIGNING_DIR:-$HOME/.whisper-signing}"
store="$dir/whisper-release.jks"
alias=whisper

if [[ -e "$store" ]]; then
  echo "A key already exists at $store — refusing to overwrite it." >&2
  exit 1
fi

read -rsp "New keystore password (12+ characters): " pass; echo
read -rsp "Same password again: " again; echo
[[ "$pass" == "$again" ]] || { echo "Passwords differ." >&2; exit 1; }
(( ${#pass} >= 12 )) || { echo "Too short." >&2; exit 1; }
export WHISPER_STORE_PASSWORD="$pass"
unset pass again

mkdir -p "$dir"
chmod 700 "$dir"
# Neutral identity: the certificate is readable by anyone from the APK.
keytool -genkeypair \
  -keystore "$store" -storetype PKCS12 \
  -storepass:env WHISPER_STORE_PASSWORD -keypass:env WHISPER_STORE_PASSWORD \
  -alias "$alias" -keyalg RSA -keysize 4096 -validity 10000 \
  -dname "CN=Whisper, O=Whisper"
chmod 600 "$store"

cat > android/key.properties <<PROPS
storeFile=$store
keyAlias=$alias
PROPS

echo
echo "Key created: $store"
echo "Certificate SHA-256 (published with each release):"
keytool -J-Duser.language=en -list -v -keystore "$store" -alias "$alias" \
  -storepass:env WHISPER_STORE_PASSWORD 2>/dev/null |
  awk -F': ' '/SHA256:/ {print $2}'
echo
echo "Back up $store and its password now."
