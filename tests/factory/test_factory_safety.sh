#!/usr/bin/env bash
# Safety net of the factory delivery (docs/modo-fabrica.md 2.d):
#  1a) second-wind-factory-deliver must NOT schedule the cleanup unless GNOME
#      Initial Setup can create the buyer's first account (binary present, GDM not
#      disabling it).
#  1b) second-wind-factory-reset must NOT delete the technician when that does not
#      hold, so the Mac is never left with no users and no way in.
#  2)  The SSH host-key step deletes the keys and regenerates them only when sshd
#      is installed.
# FAKE_ROOT, no root, no network, no poweroff.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DELIVER="$ROOT/bin/second-wind-factory-deliver"
RESET="$ROOT/factory/second-wind-factory-reset"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

# A throwaway key pair (never in the repo) and a valid batch license.
python3 "$ROOT/scripts/oem-license.py" keygen --priv "$TMP/priv.pem" >/dev/null 2>&1
KEY="$(python3 "$ROOT/scripts/oem-license.py" issue --lote REUSE-2026-11 --cantidad 1 --priv "$TMP/priv.pem" 2>/dev/null | head -1)"
export SW_OEM_PUB="$TMP/priv.pem.pub" SW_ROOT="$ROOT"
export HOME="$TMP/home" SW_STATE="$TMP/state"
mkdir -p "$TMP/home" "$TMP/state"

# --- helpers ---------------------------------------------------------------
seed_dir() { # dir: sealed system phase + valid license + gis + GDM conf
  local d="$1" conf="$2"
  mkdir -p "$d/etc/second-wind" "$d/etc/gdm3" "$d/usr/libexec" "$d/var/log"
  : > "$d/etc/second-wind/system-done"
  printf '#!/bin/sh\nexit 0\n' > "$d/usr/libexec/gnome-initial-setup"; chmod +x "$d/usr/libexec/gnome-initial-setup"
  printf '%b' "$conf" > "$d/etc/gdm3/custom.conf"
  FAKE_ROOT="$d" bash "$DELIVER" license "$KEY" >/dev/null 2>&1 || fail "seeding the test license failed"
}
deliver_yes() { FAKE_ROOT="$1" bash "$DELIVER" --yes >/dev/null 2>&1; }

# 1a) No gnome-initial-setup binary: deliver refuses and schedules nothing.
A="$TMP/a"; seed_dir "$A" '[daemon]\n'
rm -f "$A/usr/libexec/gnome-initial-setup"
deliver_yes "$A" && fail "delivered without gnome-initial-setup"
[ ! -e "$A/etc/second-wind/factory-deliver-pending" ] || fail "scheduled cleanup without gnome-initial-setup"

# 1a) InitialSetupEnable=false: deliver refuses.
B="$TMP/b"; seed_dir "$B" '[daemon]\nInitialSetupEnable=false\n'
deliver_yes "$B" && fail "delivered with InitialSetupEnable=false"
[ ! -e "$B/etc/second-wind/factory-deliver-pending" ] || fail "scheduled cleanup with InitialSetupEnable=false"

# 1a) AutomaticLoginEnable=true: deliver refuses.
B2="$TMP/b2"; seed_dir "$B2" '[daemon]\nInitialSetupEnable=true\nAutomaticLoginEnable=true\n'
deliver_yes "$B2" && fail "delivered with AutomaticLoginEnable=true"
[ ! -e "$B2/etc/second-wind/factory-deliver-pending" ] || fail "scheduled cleanup with AutomaticLoginEnable=true"

# 1a) A leftover system-mode marker: deliver refuses.
B3="$TMP/b3"; seed_dir "$B3" '[daemon]\n'
mkdir -p "$B3/var/lib"; : > "$B3/var/lib/gnome-initial-setup-done"
deliver_yes "$B3" && fail "delivered with a leftover system-mode marker"
[ ! -e "$B3/etc/second-wind/factory-deliver-pending" ] || fail "scheduled cleanup with a leftover marker"

# 1a) Everything in place (key missing): deliver proceeds and writes the key.
C="$TMP/c"; seed_dir "$C" '[daemon]\n'
deliver_yes "$C" || fail "refused a machine that is ready to deliver"
[ -e "$C/etc/second-wind/factory-deliver-pending" ] || fail "did not schedule on a ready machine"
grep -qiE '^[[:space:]]*InitialSetupEnable[[:space:]]*=[[:space:]]*true' "$C/etc/gdm3/custom.conf" \
  || fail "InitialSetupEnable=true was not written on delivery"

# --- 1b) reset must not delete the technician without a buyer path ----------
# Missing gnome-initial-setup: technician (and a usable login) survives.
D="$TMP/d"; mkdir -p "$D/etc/second-wind" "$D/etc/gdm3" "$D/etc/ssh" "$D/var/log" "$D/home/technician"
printf '[daemon]\nInitialSetupEnable=true\n' > "$D/etc/gdm3/custom.conf"
: > "$D/etc/second-wind/factory-deliver-pending"
echo notas > "$D/home/technician/notas.txt"
FAKE_ROOT="$D" bash "$RESET" || fail "reset exited non-zero when refusing"
[ -f "$D/home/technician/notas.txt" ] || fail "reset deleted the technician without a buyer account path"
[ -f "$D/var/log/second-wind-factory-reset.log" ] || fail "reset wrote no log when refusing"
grep -qi 'refusing to delete the technician' "$D/var/log/second-wind-factory-reset.log" \
  || fail "reset log lacks the refusal notice"
[ -f "$D/etc/second-wind/factory-deliver-pending" ] || fail "refusal dropped the delivery marker"

# Ready machine: the technician is deleted as intended.
E="$TMP/e"; seed_dir "$E" '[daemon]\nInitialSetupEnable=true\n'
mkdir -p "$E/home/technician"; echo notas > "$E/home/technician/notas.txt"
FAKE_ROOT="$E" bash "$RESET" || fail "reset failed on a ready machine"
[ ! -d "$E/home/technician" ] || fail "technician survived on a ready machine"

# --- 2) SSH host keys: delete, and regenerate only when sshd is present ------
# sshd absent: keys removed, ssh-keygen never invoked.
F="$TMP/f"; seed_dir "$F" '[daemon]\nInitialSetupEnable=true\n'
mkdir -p "$F/etc/ssh"; echo key > "$F/etc/ssh/ssh_host_rsa_key"
STUB_NOCALL="$TMP/stub-nocall"; printf '#!/bin/sh\ntouch "%s/nocall-called"\n' "$TMP" > "$STUB_NOCALL"; chmod +x "$STUB_NOCALL"
FAKE_ROOT="$F" SW_SSH_KEYGEN="$STUB_NOCALL" bash "$RESET" || fail "reset failed with sshd absent"
[ ! -e "$F/etc/ssh/ssh_host_rsa_key" ] || fail "old host key survived with sshd absent"
[ ! -e "$TMP/nocall-called" ] || fail "ssh-keygen was called although sshd is absent"

# sshd present: keys removed and regenerated via ssh-keygen -A.
G="$TMP/g"; seed_dir "$G" '[daemon]\nInitialSetupEnable=true\n'
mkdir -p "$G/etc/ssh" "$G/usr/sbin"; echo key > "$G/etc/ssh/ssh_host_rsa_key"
printf '#!/bin/sh\nexit 0\n' > "$G/usr/sbin/sshd"; chmod +x "$G/usr/sbin/sshd"
STUB="$TMP/stub-call"; printf '#!/bin/sh\nprintf "%%s\\n" "$*" > "%s/called-args"\n' "$TMP" > "$STUB"; chmod +x "$STUB"
FAKE_ROOT="$G" SW_SSH_KEYGEN="$STUB" bash "$RESET" || fail "reset failed with sshd present"
[ ! -e "$G/etc/ssh/ssh_host_rsa_key" ] || fail "old host key survived with sshd present"
[ "$(cat "$TMP/called-args" 2>/dev/null)" = "-A" ] || fail "ssh-keygen -A was not called with sshd present"

bash -n "$DELIVER" || fail "deliver syntax"
bash -n "$RESET" || fail "reset syntax"
echo "PASS test_factory_safety"
