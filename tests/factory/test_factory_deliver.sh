#!/usr/bin/env bash
# "Prepare for delivery" (docs/modo-fabrica.md 2.c, 3.5): refuses to deliver
# without a sealed system phase and a valid OEM license, installs the cleanup
# script + unit, and schedules the cleanup on success. FAKE_ROOT, no root, no
# network, no poweroff.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DELIVER="$ROOT/bin/second-wind-factory-deliver"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FR="$TMP/root"
fail() { echo "FAIL: $*"; exit 1; }
mkdir -p "$FR/etc/second-wind" "$TMP/home" "$TMP/state"

# A test key pair (NEVER in the repo).
python3 "$ROOT/scripts/oem-license.py" keygen --priv "$TMP/priv.pem" >/dev/null 2>&1
KEY="$(python3 "$ROOT/scripts/oem-license.py" issue --lote REUSE-2026-11 --cantidad 1 --priv "$TMP/priv.pem" 2>/dev/null | head -1)"
export FAKE_ROOT="$FR" SW_OEM_PUB="$TMP/priv.pem.pub" SW_ROOT="$ROOT"
export HOME="$TMP/home" SW_STATE="$TMP/state"

run() { bash "$DELIVER" "$@" >/dev/null 2>&1; }

# 1) Without system-done it refuses, and schedules nothing.
run --yes && fail "delivered without a sealed system phase"
[ ! -e "$FR/etc/second-wind/factory-deliver-pending" ] || fail "scheduled cleanup without system-done"

# 2) With system-done but no license it refuses.
: > "$FR/etc/second-wind/system-done"
run --yes && fail "delivered without an OEM license"
[ ! -e "$FR/etc/second-wind/factory-deliver-pending" ] || fail "scheduled cleanup without a license"

# 3) An invalid license is refused.
printf 'SWOEM1:REUSE-2026-11:0001:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\n' \
  > "$FR/etc/second-wind/license-oem"
run --yes && fail "delivered with an invalid license"
[ ! -e "$FR/etc/second-wind/factory-deliver-pending" ] || fail "scheduled cleanup with an invalid license"

# 4) The license subcommand rejects a bad key and installs a good one.
run license SWOEM1:BAD:0001:AAAA && fail "installed an invalid key"
run license "$KEY" || fail "rejected a valid OEM key"
[ -f "$FR/etc/second-wind/license-oem" ] || fail "valid key was not installed"

# 5) With everything in place it schedules the cleanup: marker, script and unit.
#    The safety net (docs/modo-fabrica.md 2.d) also needs the buyer to be able to
#    create an account: gnome-initial-setup present and GDM not disabling it. The
#    missing InitialSetupEnable key must be written as true.
mkdir -p "$FR/usr/libexec" "$FR/etc/gdm3"
printf '#!/bin/sh\nexit 0\n' > "$FR/usr/libexec/gnome-initial-setup"; chmod +x "$FR/usr/libexec/gnome-initial-setup"
printf '[daemon]\n' > "$FR/etc/gdm3/custom.conf"
run --yes || fail "delivery failed with a valid license"
[ -e "$FR/etc/second-wind/factory-deliver-pending" ] || fail "cleanup was not scheduled"
[ -x "$FR/usr/local/sbin/second-wind-factory-reset" ] || fail "cleanup script was not installed"
[ -f "$FR/etc/systemd/system/second-wind-factory-reset.service" ] || fail "cleanup unit was not installed"
grep -q 'Before=display-manager.service' "$FR/etc/systemd/system/second-wind-factory-reset.service" \
  || fail "cleanup unit does not run before GDM"
grep -q 'ConditionPathExists=/etc/second-wind/factory-deliver-pending' \
  "$FR/etc/systemd/system/second-wind-factory-reset.service" || fail "unit has no marker condition"
grep -qiE '^[[:space:]]*InitialSetupEnable[[:space:]]*=[[:space:]]*true' "$FR/etc/gdm3/custom.conf" \
  || fail "InitialSetupEnable=true was not written into custom.conf"

# 6) status reflects the state.
st="$(bash "$DELIVER" status 2>/dev/null)"
case "$st" in *"licencia OEM válida"*) ;; *) fail "status misses the license: $st" ;; esac
case "$st" in *"limpieza programada"*) ;; *) fail "status misses the scheduled cleanup: $st" ;; esac

bash -n "$DELIVER" || fail "deliver syntax"

echo "PASS test_factory_deliver"
