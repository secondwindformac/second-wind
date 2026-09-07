#!/usr/bin/env bash
# Regression guard for 47-power-defaults: wired into install.sh in BOTH modes
# (deliberately NOT gated by WITH_HARDWARE — it is user-level, needs no sudo),
# placed between 45-keyboard and 50-spotlight, present in the --only allow-list,
# and the module applies every portable key from the reference-machine brief.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INS="$ROOT/install.sh"
MOD="$ROOT/modules/47-power-defaults.sh"

[ -f "$MOD" ] || { echo "FAIL: module file missing"; exit 1; }

block="$(awk '/^MODULES=\(\)/{f=1} f{print} /^MODULES\+=\(70-apps/{exit}' "$INS")"
for hw in 1 0; do
  WITH_HARDWARE=$hw; MODULES=()
  eval "$block"
  list=" ${MODULES[*]} "
  case "$list" in *" 47-power-defaults "*) ;; *)
    echo "FAIL: 47-power-defaults missing with WITH_HARDWARE=$hw (must be ungated)"; exit 1;; esac
done
grep -m1 'ALL=(' "$INS" | grep -q '47-power-defaults' \
  || { echo "FAIL: 47-power-defaults missing from ALL allow-list"; exit 1; }

# Every portable key from the brief, applied via gset_track (tracked/reversible).
for key in sleep-inactive-ac-type sleep-inactive-ac-timeout \
           sleep-inactive-battery-type sleep-inactive-battery-timeout \
           idle-dim power-button-action power-saver-profile-on-low-battery \
           ambient-enabled idle-delay lock-enabled lock-delay; do
  grep -q "gset_track .*$key" "$MOD" || { echo "FAIL: key $key not applied"; exit 1; }
done
# Brightness must NOT be set (per-panel hardware — the brief excludes it).
# Only applied settings count; the module's comment explaining this is fine.
grep -Ei "^[^#]*(gset_track|gsettings set).*brightness" "$MOD" \
  && { echo "FAIL: brightness must not be touched"; exit 1; }
# The moved power-saver line must not remain duplicated in 40-panel.
grep -q "gset_track .*power-saver-profile-on-low-battery" "$ROOT/modules/40-panel.sh" \
  && { echo "FAIL: power-saver still duplicated in 40-panel"; exit 1; }

echo "PASS test_power_defaults_wired"
