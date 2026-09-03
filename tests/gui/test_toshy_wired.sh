#!/usr/bin/env bash
# Regression guard for the R8 root cause: modules/32-toshy.sh existed on disk
# but was never listed in install.sh's MODULES array, so the ⌘ keyboard engine
# never ran. This test asserts 32-toshy is wired in, in the right position, and
# that the module file it points at still exists.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INS="$ROOT/install.sh"

[ -f "$ROOT/modules/32-toshy.sh" ] || { echo "FAIL: modules/32-toshy.sh missing"; exit 1; }

# 1) Actually build the MODULES array the way install.sh does (hardware on),
#    then assert order: 30-extensions BEFORE 32-toshy BEFORE 45-keyboard.
block="$(awk '/^MODULES=\(\)/{f=1} f{print} /^MODULES\+=\(70-apps/{exit}' "$INS")"
WITH_HARDWARE=1; MODULES=()
eval "$block"
list=" ${MODULES[*]} "
case "$list" in *" 32-toshy "*) ;; *) echo "FAIL: 32-toshy not in MODULES (hardware mode)"; exit 1;; esac
i30=-1 i32=-1 i45=-1 n=0
for m in "${MODULES[@]}"; do
  case "$m" in 30-extensions) i30=$n;; 32-toshy) i32=$n;; 45-keyboard) i45=$n;; esac
  n=$((n+1))
done
[ "$i30" -lt "$i32" ] && [ "$i32" -lt "$i45" ] \
  || { echo "FAIL: order must be 30-extensions < 32-toshy < 45-keyboard (got $i30/$i32/$i45)"; exit 1; }

# 2) In --no-hardware mode (no admin password) Toshy is intentionally skipped.
WITH_HARDWARE=0; MODULES=()
eval "$block"
list=" ${MODULES[*]} "
case "$list" in *" 32-toshy "*) echo "FAIL: 32-toshy should be gated out under --no-hardware"; exit 1;; esac

# 3) The --only allow-list (ALL) must include 32-toshy so `--only toshy` works.
grep -m1 'ALL=(' "$INS" | grep -q '32-toshy' || { echo "FAIL: 32-toshy missing from ALL allow-list"; exit 1; }

echo "PASS test_toshy_wired"
