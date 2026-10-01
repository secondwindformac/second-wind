#!/usr/bin/env bash
# Delivery cleanup (docs/modo-fabrica.md 2.c, 3.5): with FAKE_ROOT the script
# wipes exactly what it should and nothing else, and is safe to run twice.
# Nothing here touches the real system.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RESET="$ROOT/factory/second-wind-factory-reset"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FR="$TMP/root"
fail() { echo "FAIL: $*"; exit 1; }

mkdir -p "$FR/etc/NetworkManager/system-connections" "$FR/etc/ssh" "$FR/etc/sudoers.d" \
  "$FR/etc/second-wind" "$FR/etc/skel/.config/autostart" "$FR/usr/local/share/second-wind/firstboot" \
  "$FR/var/lib/dbus" "$FR/var/log" "$FR/home/technician/.local/state/second-wind/logs" "$FR/home/buyer"

echo x > "$FR/etc/NetworkManager/system-connections/Casa-del-taller.nmconnection"
echo x > "$FR/etc/NetworkManager/system-connections/Otra.nmconnection"
echo OLD > "$FR/etc/machine-id"
echo OLD > "$FR/var/lib/dbus/machine-id"
echo key > "$FR/etc/ssh/ssh_host_rsa_key"
echo key > "$FR/etc/ssh/ssh_host_ed25519_key"
echo viejo > "$FR/etc/hostname"
echo rule > "$FR/etc/sudoers.d/zz-second-wind-gui"
echo rule > "$FR/etc/sudoers.d/zz-second-wind-toshy"
echo log > "$FR/var/log/second-wind-wifi.log"
echo junk > "$FR/home/technician/.local/state/second-wind/logs/a.log"
echo archivo > "$FR/home/technician/notas.txt"
echo keep > "$FR/home/buyer/keep.txt"
: > "$FR/etc/second-wind/factory"
: > "$FR/etc/second-wind/factory-deliver-pending"
: > "$FR/etc/second-wind/system-done"
echo '{}' > "$FR/etc/second-wind/manifest.json"
: > "$FR/etc/skel/.config/autostart/second-wind-firstboot.desktop"

FAKE_ROOT="$FR" bash "$RESET"

# 1) Technician gone, buyer untouched (safety: only the technician is removed).
[ ! -d "$FR/home/technician" ] || fail "technician home survived"
[ -f "$FR/home/buyer/keep.txt" ] || fail "an unrelated user was touched"

# 2) Saved WiFi profiles of the workshop are gone.
[ -z "$(ls -A "$FR/etc/NetworkManager/system-connections")" ] || fail "WiFi profiles survived"

# 3) Logs with workshop data are gone.
[ ! -f "$FR/var/log/second-wind-wifi.log" ] || fail "wifi log survived"
[ ! -d "$FR/home/technician" ] || fail "per-user logs survived with the home"

# 4) machine-id truncated (regenerated on the next boot).
[ ! -s "$FR/etc/machine-id" ] || fail "machine-id not truncated"
[ ! -s "$FR/var/lib/dbus/machine-id" ] || fail "dbus machine-id not truncated"

# 5) SSH host keys removed; hostname neutral.
[ ! -e "$FR/etc/ssh/ssh_host_rsa_key" ] || fail "ssh host key survived"
[ "$(cat "$FR/etc/hostname")" = "second-wind" ] || fail "hostname not neutralized"

# 6) Temporary sudoers drop-ins gone.
[ ! -e "$FR/etc/sudoers.d/zz-second-wind-gui" ] || fail "gui sudoers survived"
[ ! -e "$FR/etc/sudoers.d/zz-second-wind-toshy" ] || fail "toshy sudoers survived"

# 7) The buyer's firstboot stays armed and the system markers are correct.
[ -f "$FR/etc/skel/.config/autostart/second-wind-firstboot.desktop" ] || fail "/etc/skel not re-armed"
[ -f "$FR/etc/second-wind/system-done" ] || fail "system-done was deleted"
[ -f "$FR/etc/second-wind/manifest.json" ] || fail "system manifest was deleted"
[ ! -e "$FR/etc/second-wind/factory" ] || fail "factory marker survived (buyer would skip the user phase)"
[ ! -e "$FR/etc/second-wind/factory-deliver-pending" ] || fail "delivery marker survived"

# 8) It logs, and it is idempotent.
[ -f "$FR/var/log/second-wind-factory-reset.log" ] || fail "no log written"
FAKE_ROOT="$FR" bash "$RESET" || fail "second run failed (not idempotent)"

# 9) The script really contains every step (static check).
for pat in userdel 'NetworkManager/system-connections' '/etc/machine-id' \
           ssh_host_ 'systemctl\|journalctl' hostname skel 'factory-deliver-pending'; do
  grep -q "$pat" "$RESET" || fail "reset script lacks step: $pat"
done
bash -n "$RESET" || fail "reset script syntax"

echo "PASS test_factory_reset"
