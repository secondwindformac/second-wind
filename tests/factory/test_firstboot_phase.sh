#!/usr/bin/env bash
# firstboot phase choice (docs/modo-fabrica.md 3.3): the markers under
# /etc/second-wind decide which install.sh mode runs. No markers means the
# original one-shot flow (unchanged).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FB="$ROOT/usb/firstboot/second-wind-firstboot.sh"

BLOCK="$(sed -n '/# >>> factory-phase/,/# <<< factory-phase/p' "$FB")"
[ -n "$BLOCK" ] || { echo "FAIL: phase block not found in firstboot"; exit 1; }

run_phase() { # FACTORY_MARKER SYSTEM_DONE_MARKER
  local d; d="$(mktemp -d)"
  [ "$1" = yes ] && : > "$d/factory"
  [ "$2" = yes ] && : > "$d/system-done"
  ( SW_ETC="$d"; eval "$BLOCK"; printf '%s|%s\n' "$PHASE" "${INSTALL_ARGS:-}" )
}

[ "$(run_phase no  no)"  = "normal|--firstboot" ]                || { echo "FAIL: no markers -> $(run_phase no no)"; exit 1; }
[ "$(run_phase yes no)"  = "factory|--firstboot --factory" ]     || { echo "FAIL: factory -> $(run_phase yes no)"; exit 1; }
[ "$(run_phase yes yes)" = "skip|" ]                             || { echo "FAIL: factory+done -> $(run_phase yes yes)"; exit 1; }
[ "$(run_phase no  yes)" = "user|--firstboot --user-only" ]      || { echo "FAIL: system-done -> $(run_phase no yes)"; exit 1; }

# The wrapper must use the chosen mode and finish each phase correctly.
grep -q 'INSTALL_ARGS' "$FB"    || { echo "FAIL: firstboot ignores the phase args"; exit 1; }
grep -q 'after_success' "$FB"   || { echo "FAIL: firstboot has no per-phase finish"; exit 1; }
grep -q -- '--factory' "$FB"    || { echo "FAIL: factory mode not wired in firstboot"; exit 1; }
grep -q -- '--user-only' "$FB"  || { echo "FAIL: user-only mode not wired in firstboot"; exit 1; }
bash -n "$FB" || { echo "FAIL: firstboot syntax"; exit 1; }

echo "PASS test_firstboot_phase"
