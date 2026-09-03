#!/usr/bin/env bash
# Static checks: install.sh skips the question phase under --firstboot, and
# common.sh sources the GUI shell. (Full install needs GNOME; verified in VM.)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

grep -Eq 'ONLY_MODULES\[@\]\} -eq 0 \].*"\$FIRSTBOOT" != 1' "$ROOT/install.sh" \
  || { echo "FAIL: question phase not guarded by FIRSTBOOT"; exit 1; }
grep -q 'gui.sh' "$ROOT/lib/common.sh" \
  || { echo "FAIL: common.sh does not source gui.sh"; exit 1; }
bash -n "$ROOT/install.sh" || { echo "FAIL: install.sh syntax"; exit 1; }
bash -n "$ROOT/lib/common.sh" || { echo "FAIL: common.sh syntax"; exit 1; }
echo "PASS test_install_firstboot_flags"
