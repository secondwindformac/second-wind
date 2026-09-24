#!/usr/bin/env bash
# End-to-end test of the signed-update flow (bin/second-wind-update --apply)
# with stubs for the network (curl), the password dialog (pkexec) and the
# notifications. Checks that ONLY a payload with a valid signature from the
# embedded key gets installed, and that every other case leaves the machine
# exactly as it was.
#
# Runs with the openssl verifier always; also with the minisign verifier (and
# signatures made by the real minisign tool) when minisign is available
# (on PATH or via MINISIGN=/path/to/minisign).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
FAILS=0; PASSES=0
pass() { PASSES=$((PASSES+1)); echo "PASS: $*"; }
fail() { FAILS=$((FAILS+1)); echo "FAIL: $*"; }

MINISIGN="${MINISIGN:-$(command -v minisign || true)}"

# ---------- signing helpers (test-only; production signing is scripts/firmar-release.sh) ----------
# make_key NAME -> $T/keys/NAME.{pem,pub}  (minisign-format public key, via openssl)
make_key() {
  mkdir -p "$T/keys"
  openssl genpkey -algorithm ed25519 -out "$T/keys/$1.pem" 2>/dev/null
  head -c 8 /dev/urandom > "$T/keys/$1.id"
  { printf 'Ed'; cat "$T/keys/$1.id"
    openssl pkey -in "$T/keys/$1.pem" -pubout -outform DER 2>/dev/null | tail -c 32; } \
    | base64 -w0 > "$T/keys/$1.pub"
}
# sign_with KEYNAME FILE COMMENT OUT  (minisign "ED" format, via openssl)
sign_with() {
  local k="$T/keys/$1.pem" id="$T/keys/$1.id" f="$2" tc="$3" out="$4" s="$T/s.$$"
  openssl dgst -blake2b512 -binary "$f" > "$s.h"
  openssl pkeyutl -sign -inkey "$k" -rawin -in "$s.h" -out "$s.sig"
  { cat "$s.sig"; printf '%s' "$tc"; } > "$s.g"
  openssl pkeyutl -sign -inkey "$k" -rawin -in "$s.g" -out "$s.gsig"
  { echo "untrusted comment: test signature"
    { printf 'ED'; cat "$id"; cat "$s.sig"; } | base64 -w0; echo
    echo "trusted comment: $tc"
    base64 -w0 < "$s.gsig"; echo; } > "$out"
  rm -f "$s".*
}

# ---------- fixtures ----------
make_payload() {  # make_payload VERSION OUT_TARBALL
  local d="$T/build-$1-$$"; rm -rf "$d"; mkdir -p "$d/second-wind/bin" "$d/second-wind/lib"
  echo "$1" > "$d/second-wind/VERSION"
  printf '#!/bin/sh\nexit 0\n' > "$d/second-wind/install.sh"
  printf '#!/bin/sh\nexit 0\n' > "$d/second-wind/verify.sh"
  chmod +x "$d/second-wind/install.sh" "$d/second-wind/verify.sh"
  cp "$ROOT/lib/release-verify.sh" "$d/second-wind/lib/"
  cp "$ROOT/bin/second-wind-update" "$d/second-wind/bin/"
  tar -czf "$2" -C "$d" second-wind; rm -rf "$d"
}

# fresh_machine PUBKEY -> managed install at 0.9.4 under $T/m, stubs, HOME
fresh_machine() {
  rm -rf "$T/m" "$T/home" "$T/stub" "$T/dl"; mkdir -p "$T/m/second-wind/bin" "$T/m/second-wind/lib" "$T/home" "$T/stub" "$T/dl"
  M="$T/m/second-wind"
  echo "0.9.4" > "$M/VERSION"
  printf '#!/bin/sh\nexit 0\n' > "$M/install.sh"; printf '#!/bin/sh\nexit 0\n' > "$M/verify.sh"
  chmod +x "$M/install.sh" "$M/verify.sh"
  cp "$ROOT/lib/release-verify.sh" "$M/lib/"
  # The real updater, with only the machine location, the root check and (when
  # given) the key changed so it can run unprivileged in a temp dir.
  sed -e "s|^MANAGED_ROOT=.*|MANAGED_ROOT=\"$M\"|" \
      -e 's|\[ "\$(id -u)" -eq 0 \]|true|g' \
      ${1:+-e "s|^RELEASE_PUBKEY=.*|RELEASE_PUBKEY=\"$1\"|"} \
      "$ROOT/bin/second-wind-update" > "$M/bin/second-wind-update"
  cat > "$T/stub/curl" <<EOF
#!/bin/bash
out=""; url=""
while [ \$# -gt 0 ]; do case "\$1" in -o) out="\$2"; shift 2 ;; -m|-H|--retry) shift 2 ;; -*) shift ;; *) url="\$1"; shift ;; esac; done
case "\$url" in
  *api.github.com*) cat "$T/release.json" ;;
  *) f="$T/dl/\${url##*/}"; [ -f "\$f" ] || exit 22; if [ -n "\$out" ]; then cp "\$f" "\$out"; else cat "\$f"; fi ;;
esac
EOF
  printf '#!/bin/bash\nexec "$@"\n' > "$T/stub/pkexec"
  printf '#!/bin/bash\necho "$*" >> "%s/notify.log"\n' "$T" > "$T/stub/notify-send"
  chmod +x "$T/stub/"*
  : > "$T/notify.log"
}

release_json() {  # release_json VERSION with_sig(0|1)
  { echo "{\"tag_name\": \"v$1\", \"assets\": ["
    echo "  {\"browser_download_url\": \"https://example.invalid/dl/second-wind-$1.tar.gz\"},"
    [ "$2" = 1 ] && echo "  {\"browser_download_url\": \"https://example.invalid/dl/second-wind-$1.tar.gz.minisig\"},"
    echo "  {\"browser_download_url\": \"https://example.invalid/dl/SHA256SUMS\"}]}"; } > "$T/release.json"
}

run_apply() {
  HOME="$T/home" LANG=en_US.UTF-8 PATH="$T/stub:$PATH" SW_VERIFIER="$MODE" \
    bash "$M/bin/second-wind-update" --apply; APPLY_RC=$?
  LOG="$T/home/.local/state/second-wind/logs/updater.log"
}

assert_untouched() {  # assert_untouched CASE
  local ok=1
  [ "$(cat "$M/VERSION")" = "0.9.4" ] || ok=0
  [ ! -e "$M.prev" ] || ok=0
  [ ! -e "$T/m/.second-wind-staging" ] || ok=0
  [ "$APPLY_RC" -ne 0 ] || ok=0
  if [ $ok = 1 ]; then pass "[$MODE] $1: nothing installed, machine unchanged"
  else fail "[$MODE] $1: machine changed or rc=0 (VERSION=$(cat "$M/VERSION"), rc=$APPLY_RC)"; sed 's/^/    /' "$LOG" 2>/dev/null | tail -5; fi
}
assert_user_told() {
  grep -q "could not confirm comes from Second Wind" "$T/notify.log" \
    && pass "[$MODE] $1: person sees the clear 'not installed' message" \
    || fail "[$MODE] $1: no user message"
}

# ---------- consistency: embedded key == keys/second-wind-release.pub ----------
emb="$(sed -n 's/^RELEASE_PUBKEY="\(.*\)"$/\1/p' "$ROOT/bin/second-wind-update")"
[ -n "$emb" ] && [ "$emb" = "$(sed -n 2p "$ROOT/keys/second-wind-release.pub")" ] \
  && pass "embedded RELEASE_PUBKEY matches keys/second-wind-release.pub" \
  || fail "embedded RELEASE_PUBKEY differs from keys/second-wind-release.pub"

make_key good; make_key evil
GOOD="$(cat "$T/keys/good.pub")"

MODES="openssl"
if [ -n "$MINISIGN" ]; then
  mkdir -p "$T/mbin"; ln -sf "$MINISIGN" "$T/mbin/minisign"; export PATH="$T/mbin:$PATH"
  MODES="openssl minisign"
else
  echo "NOTE: minisign not available; minisign-verifier cases skipped"
fi

for MODE in $MODES; do
  # A. valid signature -> installs
  fresh_machine "$GOOD"; release_json 0.9.5 1
  make_payload 0.9.5 "$T/dl/second-wind-0.9.5.tar.gz"
  sign_with good "$T/dl/second-wind-0.9.5.tar.gz" "file:second-wind-0.9.5.tar.gz" "$T/dl/second-wind-0.9.5.tar.gz.minisig"
  run_apply
  if [ "$APPLY_RC" = 0 ] && [ "$(cat "$M/VERSION")" = "0.9.5" ] && [ -d "$M.prev" ] && grep -q "updated to 0.9.5" "$LOG"; then
    pass "[$MODE] A valid signature: installed 0.9.5 (previous kept for rollback)"
  else fail "[$MODE] A valid signature did not install (rc=$APPLY_RC)"; tail -5 "$LOG"; fi

  # A2. signature made by the REAL minisign tool (interop with what the owner uses)
  if [ -n "$MINISIGN" ]; then
    "$MINISIGN" -G -W -p "$T/keys/real.pub" -s "$T/keys/real.key" >/dev/null 2>&1
    fresh_machine "$(sed -n 2p "$T/keys/real.pub")"; release_json 0.9.5 1
    make_payload 0.9.5 "$T/dl/second-wind-0.9.5.tar.gz"
    "$MINISIGN" -S -s "$T/keys/real.key" -m "$T/dl/second-wind-0.9.5.tar.gz" \
      -x "$T/dl/second-wind-0.9.5.tar.gz.minisig" -t "file:second-wind-0.9.5.tar.gz" >/dev/null 2>&1
    run_apply
    [ "$APPLY_RC" = 0 ] && [ "$(cat "$M/VERSION")" = "0.9.5" ] \
      && pass "[$MODE] A2 real-minisign signature: installed" \
      || { fail "[$MODE] A2 real-minisign signature rejected"; tail -5 "$LOG"; }
  fi

  # B. payload tampered after signing
  fresh_machine "$GOOD"; release_json 0.9.5 1
  make_payload 0.9.5 "$T/dl/second-wind-0.9.5.tar.gz"
  sign_with good "$T/dl/second-wind-0.9.5.tar.gz" "file:second-wind-0.9.5.tar.gz" "$T/dl/second-wind-0.9.5.tar.gz.minisig"
  make_payload 0.9.5 "$T/dl/second-wind-0.9.5.tar.gz"   # different bytes (gzip mtime/content)
  printf 'evil' >> "$T/dl/second-wind-0.9.5.tar.gz"
  run_apply; assert_untouched "B tampered payload"; assert_user_told "B"

  # C. release without .minisig asset
  fresh_machine "$GOOD"; release_json 0.9.5 0
  make_payload 0.9.5 "$T/dl/second-wind-0.9.5.tar.gz"
  run_apply; assert_untouched "C missing signature"
  grep -q "unsigned or incomplete: refusing" "$LOG" && pass "[$MODE] C logged as unsigned" || fail "[$MODE] C not logged"

  # C2. .minisig listed but download fails
  fresh_machine "$GOOD"; release_json 0.9.5 1
  make_payload 0.9.5 "$T/dl/second-wind-0.9.5.tar.gz"
  run_apply; assert_untouched "C2 signature file unavailable"

  # D. signed by another key (attacker's own key)
  fresh_machine "$GOOD"; release_json 0.9.5 1
  make_payload 0.9.5 "$T/dl/second-wind-0.9.5.tar.gz"
  sign_with evil "$T/dl/second-wind-0.9.5.tar.gz" "file:second-wind-0.9.5.tar.gz" "$T/dl/second-wind-0.9.5.tar.gz.minisig"
  run_apply; assert_untouched "D other key"; assert_user_told "D"

  # E. placeholder key (current repo state until the owner generates the key)
  fresh_machine ""; release_json 0.9.5 1
  make_payload 0.9.5 "$T/dl/second-wind-0.9.5.tar.gz"
  sign_with good "$T/dl/second-wind-0.9.5.tar.gz" "file:second-wind-0.9.5.tar.gz" "$T/dl/second-wind-0.9.5.tar.gz.minisig"
  run_apply; assert_untouched "E placeholder key (fail closed)"
  grep -q "no release key configured" "$LOG" && pass "[$MODE] E logged 'no release key configured'" || fail "[$MODE] E reason not logged"

  # F. old validly-signed payload re-labelled as a newer version
  fresh_machine "$GOOD"; release_json 0.9.5 1
  make_payload 0.9.3 "$T/dl/second-wind-0.9.5.tar.gz"
  sign_with good "$T/dl/second-wind-0.9.5.tar.gz" "file:second-wind-0.9.3.tar.gz" "$T/dl/second-wind-0.9.5.tar.gz.minisig"
  run_apply; assert_untouched "F relabelled old release"

  # G. root half called directly with a bad signature (bypassing the user side)
  fresh_machine "$GOOD"
  make_payload 0.9.5 "$T/x.tar.gz"
  sign_with evil "$T/x.tar.gz" "file:second-wind-0.9.5.tar.gz" "$T/x.minisig"
  SW_VERIFIER="$MODE" bash "$M/bin/second-wind-update" --core-swap "$T/x.tar.gz" "$T/x.minisig" 0.9.5 >/dev/null 2>&1; APPLY_RC=$?
  LOG=/dev/null
  [ "$APPLY_RC" = 3 ] || fail "[$MODE] G root half rc=$APPLY_RC (want 3)"
  assert_untouched "G root half rejects bad signature on its own"

  # H. correctly signed name, but the payload inside says another VERSION
  fresh_machine "$GOOD"; release_json 0.9.5 1
  make_payload 0.9.6 "$T/dl/second-wind-0.9.5.tar.gz"
  sign_with good "$T/dl/second-wind-0.9.5.tar.gz" "file:second-wind-0.9.5.tar.gz" "$T/dl/second-wind-0.9.5.tar.gz.minisig"
  run_apply; assert_untouched "H payload VERSION mismatch"
done

echo
echo "passed=$PASSES failed=$FAILS"
[ "$FAILS" -eq 0 ]
