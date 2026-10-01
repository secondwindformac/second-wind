#!/usr/bin/env bash
# install.sh factory modes (docs/modo-fabrica.md 3.2): --factory picks the
# SYSTEM modules, --user-only the USER modules, and a bare run is unchanged.
# It also proves the partition: every module lies in exactly one set.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INS="$ROOT/install.sh"

SETS="$(sed -n '/# >>> factory-modes: module sets/,/# <<< factory-modes: module sets/p' "$INS")"
SEL="$(sed -n '/# >>> factory-modes: selection/,/# <<< factory-modes: selection/p' "$INS")"
[ -n "$SETS" ] || { echo "FAIL: module-sets block not found in install.sh"; exit 1; }
[ -n "$SEL" ]  || { echo "FAIL: selection block not found in install.sh"; exit 1; }

# Build MODULES the way install.sh does, for a given mode.
selection() { # FACTORY USER_ONLY WITH_HARDWARE
  local FACTORY="$1" USER_ONLY="$2" WITH_HARDWARE="$3"
  local MODULES=()
  # shellcheck disable=SC1090
  eval "$SETS"
  eval "$SEL"
  printf '%s\n' "${MODULES[*]}"
}

ALL="15-engines 20-look 30-extensions 32-toshy 35-dock 40-panel 45-keyboard 47-power-defaults 50-spotlight 55-browsers 60-hardware 62-power 65-gdm 70-apps 75-news 76-experience 80-updater 85-quiet 90-postlogin"
SYSTEM="15-engines 60-hardware 62-power 65-gdm"
USER="20-look 30-extensions 32-toshy 35-dock 40-panel 45-keyboard 47-power-defaults 50-spotlight 55-browsers 70-apps 75-news 76-experience 80-updater 85-quiet 90-postlogin"
ALL_NO_HW="20-look 30-extensions 35-dock 40-panel 45-keyboard 47-power-defaults 50-spotlight 55-browsers 70-apps 75-news 76-experience 80-updater 85-quiet 90-postlogin"

# 1) Bare run (no flags) is byte-for-byte today's behavior.
[ "$(selection 0 0 1)" = "$ALL" ] || { echo "FAIL: default (all) set changed: $(selection 0 0 1)"; exit 1; }
[ "$(selection 0 0 0)" = "$ALL_NO_HW" ] || { echo "FAIL: default --no-hardware set changed"; exit 1; }

# 2) The factory modes pick their own set regardless of the hardware gate.
[ "$(selection 1 0 1)" = "$SYSTEM" ] || { echo "FAIL: --factory set: $(selection 1 0 1)"; exit 1; }
[ "$(selection 0 1 1)" = "$USER" ]   || { echo "FAIL: --user-only set: $(selection 0 1 1)"; exit 1; }

# 3) Partition: every module is in exactly one set (no gaps, no overlap).
[ "$(selection 1 0 1 | tr ' ' '\n' | sort)" = "$(printf '%s\n' $SYSTEM | sort)" ] || exit 1
overlap=""
for m in $SYSTEM; do
  case " $USER " in *" $m "*) overlap="$overlap $m" ;; esac
done
[ -z "$overlap" ] || { echo "FAIL: module(s) in both sets:$overlap"; exit 1; }
union=" $(selection 1 0 1) $(selection 0 1 1) "
missing=""
for m in $ALL; do
  case "$union" in *" $m "*) ;; *) missing="$missing $m" ;; esac
done
[ -z "$missing" ] || { echo "FAIL: module(s) in no set:$missing"; exit 1; }

# 4) The flags exist, SW_PHASE is exported and the factory seals the machine.
grep -q -- '--factory)' "$INS"   || { echo "FAIL: --factory flag not parsed"; exit 1; }
grep -q -- '--user-only)' "$INS" || { echo "FAIL: --user-only flag not parsed"; exit 1; }
grep -q 'export SW_PHASE' "$INS" || { echo "FAIL: SW_PHASE not exported"; exit 1; }
grep -q 'SW_PHASE=system' "$INS" || { echo "FAIL: no system phase"; exit 1; }
grep -q 'SW_PHASE=user' "$INS"   || { echo "FAIL: no user phase"; exit 1; }
grep -q 'SW_PHASE=all' "$INS"    || { echo "FAIL: no all (default) phase"; exit 1; }
grep -q '/etc/second-wind/system-done' "$INS" \
  || { echo "FAIL: factory does not seal with system-done"; exit 1; }

echo "PASS test_install_split"
