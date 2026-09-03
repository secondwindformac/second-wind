#!/usr/bin/env bash
# Static checks on the firstboot GUI orchestration (full flow verified in VM).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FB="$ROOT/usb/firstboot/second-wind-firstboot.sh"

grep -q 'gui_available' "$FB"     || { echo "FAIL: no gui_available gate"; exit 1; }
grep -q 'gui_consent'   "$FB"     || { echo "FAIL: no consent"; exit 1; }
grep -q 'gui_auth_begin' "$FB"    || { echo "FAIL: no one-time auth"; exit 1; }
grep -q 'gui_progress_open' "$FB" || { echo "FAIL: no progress window"; exit 1; }
grep -q 'SW_UI=gui' "$FB"         || { echo "FAIL: install not run in gui mode"; exit 1; }
grep -q 'gnome-terminal' "$FB"    || { echo "FAIL: terminal fallback removed"; exit 1; }
grep -q 'lib/common.sh' "$FB"     || { echo "FAIL: firstboot does not load helpers"; exit 1; }
bash -n "$FB" || { echo "FAIL: firstboot syntax"; exit 1; }

# i18n keys used by the GUI flow must resolve in BOTH languages.
for L in en es; do
  out="$(cd "$ROOT" && LANG=$L.UTF-8 bash -c 'source lib/common.sh 2>/dev/null; \
    for k in gui_ok gui_cancel gui_consent gui_phase_prep gui_err_body gui_err_log; do \
      [ -n "${MSG[$k]:-}" ] || { echo "MISSING:$k"; exit 1; }; done; echo OK')"
  [ "$out" = "OK" ] || { echo "FAIL: i18n $L -> $out"; exit 1; }
done
echo "PASS test_firstboot_flow"
