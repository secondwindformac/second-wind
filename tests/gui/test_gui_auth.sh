#!/usr/bin/env bash
# Stub-based test: one-time askpass auth + temporary NOPASSWD sudoers rule
# (robust against `sudo -k`), removed on end. No root needed.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/zenity" <<'EOF'
#!/bin/sh
case "$*" in *--password*) echo "s3cr3t";; *) : ;; esac
exit 0
EOF
cat > "$TMP/sudo" <<'EOF'
#!/bin/sh
printf '%s ' "$@" >> "$SUDO_LOG"; echo >> "$SUDO_LOG"
exit 0
EOF
chmod +x "$TMP/zenity" "$TMP/sudo"
export PATH="$TMP:$PATH" SUDO_LOG="$TMP/sudo.log" DISPLAY=":0"
declare -A MSG=()
source "$ROOT/lib/gui.sh"

gui_auth_begin || { echo "FAIL: auth_begin"; exit 1; }
[ -n "${SUDO_ASKPASS:-}" ] && [ -x "$SUDO_ASKPASS" ] || { echo "FAIL: askpass not set"; exit 1; }
out="$("$SUDO_ASKPASS")"; [ "$out" = "s3cr3t" ] || { echo "FAIL: askpass stdout"; exit 1; }
grep -q "s3cr3t" "$SUDO_ASKPASS" && { echo "FAIL: password stored in helper"; exit 1; }
grep -q -- "-A -v" "$SUDO_LOG" || { echo "FAIL: sudo -A -v not called"; exit 1; }
grep -q "tee /etc/sudoers.d/zz-second-wind-gui" "$SUDO_LOG" || { echo "FAIL: NOPASSWD rule not written"; exit 1; }
gui_auth_ensure || { echo "FAIL: ensure ok path"; exit 1; }
askpass_path="$SUDO_ASKPASS"
gui_auth_end
grep -q "rm -f /etc/sudoers.d/zz-second-wind-gui" "$SUDO_LOG" || { echo "FAIL: NOPASSWD rule not removed"; exit 1; }
[ -e "$askpass_path" ] && { echo "FAIL: askpass not cleaned"; exit 1; }
echo "PASS test_gui_auth"
