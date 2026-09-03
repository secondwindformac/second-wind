#!/usr/bin/env bash
# Stub-based test for sw_sudo_ready (lib/common.sh) — the R6 blocker-B fix.
# The bug: modules guarded with a bare `sudo -v`, which re-prompts for a
# password EVEN with a NOPASSWD rule in place (after Toshy's `sudo -k`).
# sw_sudo_ready must succeed via `sudo -n true` when that rule exists, and
# NEVER fall through to the prompting `sudo -v` in that case.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# Stub sudo: log the invocation and honour env-controlled exit codes so each
# branch of sw_sudo_ready can be exercised deterministically.
cat > "$TMP/sudo" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$SUDO_LOG"
case "$1 $2" in
  "-n true")  [ "${STUB_NOPASSWD:-1}" = 0 ] && exit 0 || exit 1 ;;
  "-A -v")    [ "${STUB_ASKPASS_OK:-1}" = 0 ] && exit 0 || exit 1 ;;
  "-v"*)      [ "${STUB_V_OK:-0}" = 0 ] && exit 0 || exit 1 ;;
  *)          exit 0 ;;
esac
EOF
chmod +x "$TMP/sudo"; export PATH="$TMP:$PATH"
# common.sh sources i18n / gui; harmless here. Load just the helper we test by
# sourcing common.sh in a minimal SW_ROOT.
export SW_ROOT="$ROOT" SUDO_LOG="$TMP/sudo.log"
# shellcheck disable=SC1091
source "$ROOT/lib/common.sh"

# --- Case 1: NOPASSWD rule present (GUI firstboot) → no prompt, no `sudo -v` ---
: > "$SUDO_LOG"; STUB_NOPASSWD=0 sw_sudo_ready || { echo "FAIL: NOPASSWD path did not succeed"; exit 1; }
grep -q -- "-n true" "$SUDO_LOG" || { echo "FAIL: did not try 'sudo -n true' first"; exit 1; }
grep -qx -- "-v" "$SUDO_LOG" && { echo "FAIL: fell through to prompting 'sudo -v' despite NOPASSWD"; exit 1; }

# --- Case 2: no NOPASSWD but graphical askpass works (GUI edge) → no `sudo -v` ---
: > "$SUDO_LOG"; SUDO_ASKPASS=/bin/true STUB_NOPASSWD=1 STUB_ASKPASS_OK=0 sw_sudo_ready \
  || { echo "FAIL: askpass path did not succeed"; exit 1; }
grep -q -- "-A -v" "$SUDO_LOG" || { echo "FAIL: did not try graphical 'sudo -A -v'"; exit 1; }
grep -qx -- "-v" "$SUDO_LOG" && { echo "FAIL: fell through to bare 'sudo -v' when askpass worked"; exit 1; }

# --- Case 3: standalone terminal (no rule, no askpass) → one interactive `sudo -v` ---
: > "$SUDO_LOG"; unset SUDO_ASKPASS; STUB_NOPASSWD=1 STUB_V_OK=0 sw_sudo_ready \
  || { echo "FAIL: terminal fallback did not succeed"; exit 1; }
grep -qx -- "-v" "$SUDO_LOG" || { echo "FAIL: standalone did not fall back to 'sudo -v'"; exit 1; }

# --- Case 4: everything denied → non-zero (module aborts loudly, never silent) ---
: > "$SUDO_LOG"; STUB_NOPASSWD=1 STUB_V_OK=1 sw_sudo_ready \
  && { echo "FAIL: should return non-zero when no auth path works"; exit 1; }

echo "PASS test_sudo_ready"
