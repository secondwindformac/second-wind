#!/usr/bin/env bash
# System manifest (docs/modo-fabrica.md 3.4): in the factory phase the SYSTEM
# changes are recorded in /etc/second-wind/manifest.json (not in the home), and
# uninstall.sh sees them through the merged reads. A bare run is unchanged.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

SANDBOX="$(mktemp -d)"
export HOME="$SANDBOX/home"
mkdir -p "$HOME"
export SW_ROOT="$ROOT"
export SW_STATE="$SANDBOX/state"
export SW_MANIFEST="$SW_STATE/manifest.json"
export SW_MANIFEST_SYSTEM="$SANDBOX/etc-sw/manifest.json"

# shellcheck source=/dev/null
source "$ROOT/lib/common.sh"
# The factory writes the SYSTEM manifest as root; here we run it as this user.
sudo() { "$@"; }

json_get() { python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1])).get(sys.argv[2])))' "$1" "$2"; }

# 1) Factory phase: system records land in the SYSTEM manifest, not the home.
SW_PHASE=system
mf apt-installed foo
mf system-file /etc/second-wind/foo.conf
[ -f "$SW_MANIFEST_SYSTEM" ] || { echo "FAIL: system manifest was not written"; exit 1; }
[ ! -f "$SW_MANIFEST" ] || { echo "FAIL: system phase wrote the home manifest"; exit 1; }
[ "$(json_get "$SW_MANIFEST_SYSTEM" apt_packages)" = '["foo"]' ] || { echo "FAIL: apt not in system manifest"; exit 1; }

# 2) Default run: unchanged, everything still goes to the home manifest.
SW_PHASE=all
mf apt-installed bar
[ "$(json_get "$SW_MANIFEST" apt_packages)" = '["bar"]' ] || { echo "FAIL: default run no longer writes the home manifest"; exit 1; }
[ "$(json_get "$SW_MANIFEST_SYSTEM" apt_packages)" = '["foo"]' ] || { echo "FAIL: default run touched the system manifest"; exit 1; }

# 3) uninstall finds both: the merged reads union the two manifests.
merged="$(python3 "$ROOT/lib/manifest.py" merged-get apt_packages)"
case "$merged" in *'"foo"'*'"bar"'*|*'"bar"'*'"foo"'*) ;; *) echo "FAIL: merged-get missed an entry: $merged"; exit 1;; esac

SW_PHASE=system
mf note "swap-resized"          # a system marker (62-power style)
python3 "$ROOT/lib/manifest.py" merged-has-note "swap-resized" || { echo "FAIL: merged-has-note missed the system note"; exit 1; }
python3 "$ROOT/lib/manifest.py" has-note "swap-resized" 2>/dev/null && { echo "FAIL: note unexpectedly in the home manifest"; exit 1; }

# 4) uninstall.sh actually uses the merged reads.
grep -q 'merged-get apt_packages' "$ROOT/uninstall.sh"   || { echo "FAIL: uninstall does not merge apt"; exit 1; }
grep -q 'merged-get system' "$ROOT/uninstall.sh"         || { echo "FAIL: uninstall does not merge system files"; exit 1; }
grep -q 'merged-has-note' "$ROOT/uninstall.sh"           || { echo "FAIL: uninstall does not merge notes"; exit 1; }

# 5) Legacy: a machine with only a home manifest still resolves (back-compat).
rm -f "$SW_MANIFEST_SYSTEM"
[ "$(python3 "$ROOT/lib/manifest.py" merged-get apt_packages)" = '["bar"]' ] || { echo "FAIL: legacy (home-only) merged read broke"; exit 1; }

echo "PASS test_system_manifest"
