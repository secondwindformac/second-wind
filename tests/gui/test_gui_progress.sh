#!/usr/bin/env bash
# Stub-based test: phase progress window over a FIFO, including the two bugs the
# VM E2E caught — (C) exported FIFO path must survive a re-source; (A) close must
# not hang when a long-lived process (e.g. ulauncher) keeps the FIFO open.
# The stub reads line-by-line and flushes immediately (like zenity updating its
# GUI live), so lines survive the kill-based close.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/zenity" <<'EOF'
#!/bin/sh
while IFS= read -r line; do printf '%s\n' "$line" >> "$ZP_LOG"; done
EOF
chmod +x "$TMP/zenity"; export PATH="$TMP:$PATH" ZP_LOG="$TMP/zp.log" DISPLAY=":0"
declare -A MSG=()
source "$ROOT/lib/gui.sh"

# --- normal phase updates land in the reader ---
gui_progress_open "Working"
[ -p "${SW_PROGRESS_FIFO:-/none}" ] || { echo "FAIL: fifo missing"; exit 1; }
gui_progress_update "Preparando"
gui_progress_update "Instalando"
sleep 0.5                                     # let the reader consume before close
gui_progress_close
grep -q "# Preparando" "$ZP_LOG" || { echo "FAIL: phase 1 missing"; exit 1; }
grep -q "# Instalando" "$ZP_LOG" || { echo "FAIL: phase 2 missing"; exit 1; }
[ -e "${SW_PROGRESS_FIFO:-}" ] && { echo "FAIL: fifo not cleaned"; exit 1; }
gui_progress_update "late" || { echo "FAIL: update-after-close errored"; exit 1; }

# --- (C) exported FIFO path survives a re-source (the install.sh child case) ---
(
  export SW_PROGRESS_FIFO="/tmp/sw-fifo-preserve-check"
  source "$ROOT/lib/gui.sh"
  [ "$SW_PROGRESS_FIFO" = "/tmp/sw-fifo-preserve-check" ] \
    || { echo "FAIL: exported FIFO path clobbered on re-source"; exit 1; }
)

# --- (A) close must NOT hang if a long-lived writer keeps the FIFO open ---
gui_progress_open "Working2"
( exec 9>"$SW_PROGRESS_FIFO"; sleep 30 ) &   # simulate ulauncher holding the fd
LINGER=$!
gui_progress_update "Fase"
sleep 0.3
gui_progress_close                            # kills the reader → returns, no hang
kill "$LINGER" 2>/dev/null || true
echo "PASS test_gui_progress"
