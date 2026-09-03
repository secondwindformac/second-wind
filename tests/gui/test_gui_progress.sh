#!/usr/bin/env bash
# Stub-based test: phase progress window fed via a FIFO (no GNOME needed).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/zenity" <<'EOF'
#!/bin/sh
# emulate --progress: drain stdin into a log until EOF
cat >> "$ZP_LOG"
EOF
chmod +x "$TMP/zenity"; export PATH="$TMP:$PATH" ZP_LOG="$TMP/zp.log" DISPLAY=":0"
declare -A MSG=()
source "$ROOT/lib/gui.sh"

gui_progress_open "Working"
[ -p "${SW_PROGRESS_FIFO:-/none}" ] || { echo "FAIL: fifo missing"; exit 1; }
gui_progress_update "Preparando"
gui_progress_update "Instalando"
gui_progress_close
grep -q "# Preparando" "$ZP_LOG" || { echo "FAIL: phase 1 missing"; exit 1; }
grep -q "# Instalando" "$ZP_LOG" || { echo "FAIL: phase 2 missing"; exit 1; }
[ -e "${SW_PROGRESS_FIFO:-}" ] && { echo "FAIL: fifo not cleaned"; exit 1; }
gui_progress_update "late" || { echo "FAIL: update-after-close errored"; exit 1; }
echo "PASS test_gui_progress"
