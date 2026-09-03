#!/usr/bin/env bash
# Test that ui_step/ui_error route to the GUI only when SW_UI=gui.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export CALLS="$TMP/calls"; : > "$CALLS"
C_INFO=""; C_OFF=""
# fake gui_* so we test ROUTING only (not the real dialogs)
gui_progress_update(){ echo "PROG:$1" >> "$CALLS"; }
gui_error(){ echo "ERR:$1" >> "$CALLS"; }

# terminal mode: ui_step prints a line, does NOT touch the GUI
SW_UI=terminal
source "$ROOT/lib/ui.sh"
out="$(ui_step 3 17 "Instalando")"
echo "$out" | grep -q "\[3/17\] Instalando" || { echo "FAIL: terminal step line"; exit 1; }
grep -q PROG "$CALLS" && { echo "FAIL: terminal must not call progress"; exit 1; }

# gui mode: ui_step -> gui_progress_update; ui_error -> gui_error
: > "$CALLS"; SW_UI=gui
ui_step 4 17 "Afinando"; grep -q "PROG:Afinando" "$CALLS" || { echo "FAIL: gui step routing"; exit 1; }
ui_error "boom"; grep -q "ERR:boom" "$CALLS" || { echo "FAIL: gui error routing"; exit 1; }
echo "PASS test_ui_routing"
