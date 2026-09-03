#!/usr/bin/env bash
# Stub-based test: gui_available / gui_consent / gui_error (no GNOME needed).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/zenity" <<'EOF'
#!/bin/sh
printf '%s\0' "$@" >> "$ZENITY_LOG"
exit "${ZENITY_RC:-0}"
EOF
chmod +x "$TMP/zenity"; export PATH="$TMP:$PATH" ZENITY_LOG="$TMP/z.log"
export DISPLAY=":0"; declare -A MSG=([gui_err_title]="Error" [gui_err_log]="Log:")
source "$ROOT/lib/gui.sh"

gui_available || { echo "FAIL: gui_available should be true"; exit 1; }
ZENITY_RC=0 gui_consent "body" || { echo "FAIL: consent yes"; exit 1; }
ZENITY_RC=1 gui_consent "body" && { echo "FAIL: consent no"; exit 1; }
: > "$ZENITY_LOG"; gui_error "boom" "/tmp/log"
grep -qz -- "--error" "$ZENITY_LOG" || { echo "FAIL: error dialog"; exit 1; }
grep -qz -- "boom" "$ZENITY_LOG" || { echo "FAIL: error body"; exit 1; }
echo "PASS test_gui_basics"
