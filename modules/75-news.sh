#!/usr/bin/env bash
# 75-news — the project's polite heartbeat. A weekly user-level systemd timer
# that (a) tells the user when a new Second Wind release exists and (b) ONCE,
# after 30 days of happy use, asks if they'd like to support the project.
# Ethics baked in: one-shot nudge, visible opt-out (Second Wind Apps → switch,
# or the notification's own button), zero third-party ads, zero telemetry —
# nothing is sent anywhere; checks are a public releases lookup.

if [ "$DRY_RUN" = 1 ]; then
  info "${MSG[m75_dry]}"
  return 0
fi

NEWS_DIR="$SW_STATE/news"
UNIT_DIR="$HOME/.config/systemd/user"
mkdir -p "$NEWS_DIR" "$UNIT_DIR"

[ -f "$NEWS_DIR/install-date" ] || date +%s > "$NEWS_DIR/install-date"
cp "$SW_ROOT/links.conf" "$SW_STATE/links.conf" 2>/dev/null || true

cat > "$NEWS_DIR/second-wind-news.sh" <<'EOF'
#!/bin/bash
# Second Wind news heartbeat (weekly). Self-contained; respects opt-out.
SW_STATE="$HOME/.local/state/second-wind"
NEWS="$SW_STATE/news"

# --test: show the sample support notice (no state changes) — used by the
# "Try the notice now" row in Second Wind Apps.
if [ "${1:-}" = "--test" ]; then
  case "${LANG:-en}" in
    es*) B="Tu Mac lleva un mes de segunda vida 💨 ¿Nos ayudas a revivir un millón más? (esto es una PRUEBA)"; S="Apoyar"; N="Cerrar" ;;
    *)   B="Your Mac has enjoyed a month of second life 💨 Help us revive a million more? (this is a TEST)"; S="Support"; N="Close" ;;
  esac
  DONATE_URL="https://github.com/arancibiamartin/second-wind"
  [ -f "$SW_STATE/links.conf" ] && . "$SW_STATE/links.conf"
  R=$(notify-send -a "Second Wind" -i emblem-favorite -A support="$S" -A close="$N" "Second Wind" "$B" 2>/dev/null)
  [ "$R" = "support" ] && xdg-open "$DONATE_URL" &
  exit 0
fi

[ -f "$SW_STATE/news-optout" ] && exit 0

DONATE_URL="https://github.com/arancibiamartin/second-wind"
[ -f "$SW_STATE/links.conf" ] && . "$SW_STATE/links.conf"
REPO_API="https://api.github.com/repos/arancibiamartin/second-wind/releases/latest"

case "${LANG:-en}" in
  es*)
    T_UPD="Hay una versión nueva de Second Wind"; T_UPD_B="Ver novedades"
    T_THANKS="Tu Mac lleva un mes de segunda vida 💨 ¿Nos ayudas a revivir un millón más?"
    T_SUP="Apoyar"; T_NO="No volver a mostrar" ;;
  *)
    T_UPD="A new Second Wind release is available"; T_UPD_B="See what's new"
    T_THANKS="Your Mac has enjoyed a month of second life 💨 Help us revive a million more?"
    T_SUP="Support"; T_NO="Don't show again" ;;
esac

# (a) Update notice — silent no-op while the repository is private
LATEST="$(curl -fsSL -m 10 "$REPO_API" 2>/dev/null | grep -m1 '"tag_name"' | cut -d'"' -f4)"
if [ -n "$LATEST" ] && [ "$LATEST" != "$(cat "$NEWS/last-seen-release" 2>/dev/null)" ]; then
  echo "$LATEST" > "$NEWS/last-seen-release"
  R=$(notify-send -a "Second Wind" -i software-update-available \
        -A open="$T_UPD_B" "Second Wind" "$T_UPD ($LATEST)" 2>/dev/null)
  [ "$R" = "open" ] && xdg-open "https://github.com/arancibiamartin/second-wind/releases" &
fi

# (b) One-time 30-day support nudge
if [ ! -f "$NEWS/nudged" ] && [ -f "$NEWS/install-date" ]; then
  AGE=$(( ( $(date +%s) - $(cat "$NEWS/install-date") ) / 86400 ))
  if [ "$AGE" -ge 30 ]; then
    touch "$NEWS/nudged"
    R=$(notify-send -a "Second Wind" -i emblem-favorite \
          -A support="$T_SUP" -A never="$T_NO" "Second Wind" "$T_THANKS" 2>/dev/null)
    case "$R" in
      support) xdg-open "$DONATE_URL" & ;;
      never)   touch "$SW_STATE/news-optout" ;;
    esac
  fi
fi
exit 0
EOF
chmod +x "$NEWS_DIR/second-wind-news.sh"
track_new_file "$NEWS_DIR"

cat > "$UNIT_DIR/second-wind-news.service" <<EOF
[Unit]
Description=Second Wind news heartbeat
[Service]
Type=oneshot
ExecStart=$NEWS_DIR/second-wind-news.sh
EOF
cat > "$UNIT_DIR/second-wind-news.timer" <<'EOF'
[Unit]
Description=Second Wind weekly news check
[Timer]
OnBootSec=15min
OnUnitActiveSec=1w
Persistent=true
[Install]
WantedBy=timers.target
EOF
track_new_file "$UNIT_DIR/second-wind-news.service"
track_new_file "$UNIT_DIR/second-wind-news.timer"

systemctl --user daemon-reload 2>/dev/null || true
systemctl --user enable --now second-wind-news.timer >/dev/null 2>&1 || true

ok "${MSG[m75_ok]}"
