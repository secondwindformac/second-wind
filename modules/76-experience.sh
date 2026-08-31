#!/usr/bin/env bash
# 76-experience — the Mac Experience trial clock. Everything premium ships ON
# (transparently announced); a daily user timer runs `second-wind-experience
# check`, which flips the courtesy lock on day 30 unless a license was
# activated from the store. The switch itself lives in bin/second-wind-experience.

if [ "$DRY_RUN" = 1 ]; then
  info "${MSG[m76_dry]}"
  return 0
fi

EXP_DIR="$SW_STATE/experience"
UNIT_DIR="$HOME/.config/systemd/user"
mkdir -p "$EXP_DIR" "$UNIT_DIR"

# Trial clock: reuse the news install date so both heartbeats agree.
if [ ! -f "$EXP_DIR/trial_since" ]; then
  if [ -f "$SW_STATE/news/install-date" ]; then
    cp "$SW_STATE/news/install-date" "$EXP_DIR/trial_since"
  else
    date +%s > "$EXP_DIR/trial_since"
  fi
fi
[ -f "$EXP_DIR/state" ] || echo trial > "$EXP_DIR/state"
track_new_file "$EXP_DIR"

cat > "$UNIT_DIR/second-wind-experience.service" <<EOF
[Unit]
Description=Second Wind Mac Experience daily check
[Service]
Type=oneshot
ExecStart=$SW_ROOT/bin/second-wind-experience check
EOF
# OnCalendar (not monotonic) so Persistent=true really catches missed days;
# the boot trigger covers machines that are only on for short stretches.
cat > "$UNIT_DIR/second-wind-experience.timer" <<'EOF'
[Unit]
Description=Second Wind Mac Experience trial timer
[Timer]
OnCalendar=daily
OnBootSec=10min
Persistent=true
[Install]
WantedBy=timers.target
EOF
track_new_file "$UNIT_DIR/second-wind-experience.service"
track_new_file "$UNIT_DIR/second-wind-experience.timer"

systemctl --user daemon-reload 2>/dev/null || true
systemctl --user enable --now second-wind-experience.timer >/dev/null 2>&1 || true

ok "${MSG[m76_ok]}"
