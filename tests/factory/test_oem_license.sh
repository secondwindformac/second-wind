#!/usr/bin/env bash
# OEM license (docs/modo-fabrica.md 3.6, 4.1): offline Ed25519 issue/verify,
# rejection of tampered keys and of the shipped placeholder, and the split from
# the normal US$10 activation. No root, no network. Key pair lives in mktemp.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

# --- key pair + batch (NEVER in the repo) ------------------------------------
python3 "$ROOT/scripts/oem-license.py" keygen --priv "$TMP/oem-priv.pem" >/dev/null 2>&1
PUB="$TMP/oem-priv.pem.pub"
[ -f "$PUB" ] || fail "keygen did not write the public key"

keys="$(python3 "$ROOT/scripts/oem-license.py" issue --lote REUSE-2026-11 --cantidad 3 --priv "$TMP/oem-priv.pem" 2>/dev/null)"
KEY1="$(printf '%s\n' "$keys" | sed -n '1p')"
KEY2="$(printf '%s\n' "$keys" | sed -n '2p')"
[ "$(printf '%s\n' "$keys" | grep -c '^SWOEM1:')" = "3" ] || fail "issue did not emit 3 keys"
case "$KEY1" in SWOEM1:REUSE-2026-11:0001:*) ;; *) fail "key 1 shape: $KEY1" ;; esac
case "$KEY2" in SWOEM1:REUSE-2026-11:0002:*) ;; *) fail "key 2 serial: $KEY2" ;; esac

# --- valid key verifies; batch + serial are read back -------------------------
out="$(python3 "$ROOT/lib/oem_license.py" verify-key "$PUB" "$KEY1")" || fail "valid key rejected"
case "$out" in *"batch=REUSE-2026-11"*"serial=0001"*) ;; *) fail "verify output: $out" ;; esac

# --- tampered signature is rejected ------------------------------------------
BADSIG="$(python3 -c 'import sys;k=sys.argv[1];h,s=k.rsplit(":",1);s=("B" if s[0]=="A" else "A")+s[1:];print(h+":"+s)' "$KEY1")"
python3 "$ROOT/lib/oem_license.py" verify-key "$PUB" "$BADSIG" >/dev/null 2>&1 \
  && fail "tampered signature accepted"

# --- tampered batch is rejected (the signature covers it) ---------------------
BADBATCH="$(python3 -c 'import sys;k=sys.argv[1];_,b,s,sig=k.split(":",3);print("SWOEM1:OTRO-LOTE:"+s+":"+sig)' "$KEY1")"
python3 "$ROOT/lib/oem_license.py" verify-key "$PUB" "$BADBATCH" >/dev/null 2>&1 \
  && fail "tampered batch accepted"

# --- the shipped placeholder public key rejects everything --------------------
python3 "$ROOT/lib/oem_license.py" verify-key "$ROOT/assets/oem-pub.pem" "$KEY1" >/dev/null 2>&1 \
  && fail "placeholder public key accepted a real key"

# --- the normal (Lemon) activation is untouched, and rejects OEM keys ---------
mkdir -p "$TMP/bin" "$TMP/home" "$TMP/state" "$TMP/etc-sw"
cat > "$TMP/bin/curl" <<'EOF'
#!/bin/sh
printf 'called\n' >> "$CURL_LOG"
printf '{"error":"license_key not found"}\n404\n'
EOF
chmod +x "$TMP/bin/curl"
export PATH="$TMP/bin:$PATH" CURL_LOG="$TMP/curl.log"
export HOME="$TMP/home" SW_STATE="$TMP/state" SW_ETC="$TMP/etc-sw" SW_ROOT="$ROOT"

# A normal-looking key still goes to Lemon (the flow is unchanged) and fails.
CURL_LOG="$TMP/normal.log"
: > "$CURL_LOG"
if bash "$ROOT/bin/second-wind-experience" activate NOT-A-REAL-KEY >/dev/null 2>&1; then
  fail "a bogus normal key was accepted offline"
fi
[ -s "$CURL_LOG" ] || fail "the normal activation no longer reaches the network"
[ ! -f "$SW_STATE/experience/license.hash" ] || fail "bogus normal key stored a license"

# An OEM key never reaches the network and is rejected by the normal flow.
CURL_LOG="$TMP/oem.log"
: > "$CURL_LOG"
if bash "$ROOT/bin/second-wind-experience" activate "$KEY1" >/dev/null 2>&1; then
  fail "the normal activation accepted an OEM key"
fi
[ -s "$CURL_LOG" ] && fail "an OEM key reached the network"
[ ! -f "$SW_STATE/experience/license.hash" ] || fail "an OEM key stored a license in the home"

# --- a valid OEM license activates the Experience, offline --------------------
export SW_OEM_PUB="$PUB" SW_OEM_LICENSE="$TMP/oem-license"
printf '%s\n' "$KEY1" > "$SW_OEM_LICENSE"
rm -rf "$SW_STATE/experience"
[ "$(bash "$ROOT/bin/second-wind-experience" status)" = "active (oem)" ] \
  || fail "OEM license did not activate the Experience"

# A tampered OEM license does not activate it.
printf '%s\n' "$BADSIG" > "$SW_OEM_LICENSE"
case "$(bash "$ROOT/bin/second-wind-experience" status)" in
  "active (oem)") fail "a tampered OEM license still activated the Experience" ;;
esac

echo "PASS test_oem_license"
