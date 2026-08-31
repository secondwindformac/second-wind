#!/usr/bin/env bash
# 80-updater — arms the weekly self-update check (USB-installed machines).
# The heavy lifting lives in bin/second-wind-update: one notification when a
# new release exists, one password dialog to apply, automatic rollback if the
# post-update health check regresses. Developer git clones are detected there
# and skipped, so arming this everywhere is harmless.

if [ "$DRY_RUN" = 1 ]; then
  info "${MSG[m80_dry]}"
  return 0
fi

UNIT_DIR="$HOME/.config/systemd/user"
mkdir -p "$UNIT_DIR"

cat > "$UNIT_DIR/second-wind-update.service" <<EOF
[Unit]
Description=Second Wind update check
[Service]
Type=oneshot
ExecStart=/bin/bash $SW_ROOT/bin/second-wind-update --check
EOF

cat > "$UNIT_DIR/second-wind-update.timer" <<'EOF'
[Unit]
Description=Second Wind weekly update check
[Timer]
OnBootSec=25min
OnUnitActiveSec=1w
Persistent=true
[Install]
WantedBy=timers.target
EOF
track_new_file "$UNIT_DIR/second-wind-update.service"
track_new_file "$UNIT_DIR/second-wind-update.timer"

systemctl --user daemon-reload 2>/dev/null || true
systemctl --user enable --now second-wind-update.timer >/dev/null 2>&1 || true

ok "${MSG[m80_ok]}"
