#!/usr/bin/env bash
# 75-news — the project's polite heartbeat. A weekly user-level systemd timer
# that (a) tells the user when a new Second Wind release exists and (b) ONCE,
# after 30 days of happy use, asks if they'd like to support the project.
# Ethics baked in: one-shot nudge, visible opt-out (Second Wind app → ⋯ menu,
# or the notification's own button), zero third-party ads, zero telemetry —
# Second Wind does not send your data: it only checks for improvements (a
# public releases lookup), downloads the store's icons and activates your
# license when you ask it to. (Wording agreed 24-Sep: "sends nothing" was
# not literally true.)

if [ "$DRY_RUN" = 1 ]; then
  info "${MSG[m75_dry]}"
  return 0
fi

NEWS_DIR="$SW_STATE/news"
UNIT_DIR="$HOME/.config/systemd/user"
mkdir -p "$NEWS_DIR" "$UNIT_DIR"

[ -f "$NEWS_DIR/install-date" ] || date +%s > "$NEWS_DIR/install-date"
# Where the updater lives, for the update notice's button (the heartbeat
# script below is self-contained and does not know SW_ROOT).
echo "$SW_ROOT/bin/second-wind-update" > "$NEWS_DIR/updater"
cp "$SW_ROOT/links.conf" "$SW_STATE/links.conf" 2>/dev/null || true

cat > "$NEWS_DIR/second-wind-news.sh" <<'EOF'
#!/bin/bash
# Second Wind news heartbeat (weekly). Self-contained; respects opt-out.
SW_STATE="$HOME/.local/state/second-wind"
NEWS="$SW_STATE/news"

# --test: show the sample support notice (no state changes) — used by the
# "Try the notice now" item in the Second Wind app (⋯ menu).
if [ "${1:-}" = "--test" ]; then
  case "${LANG:-en}" in
    es*) B="Tu Mac lleva un mes de segunda vida 💨 ¿Nos ayudas a revivir un millón más? (esto es una PRUEBA)"; S="Apoyar"; N="Cerrar" ;;
    *)   B="Your Mac has enjoyed a month of second life 💨 Help us revive a million more? (this is a TEST)"; S="Support"; N="Close" ;;
  esac
  DONATE_URL="https://secondwindformac.com/"
  [ -f "$SW_STATE/links.conf" ] && . "$SW_STATE/links.conf"
  R=$(timeout 3600 notify-send -a "Second Wind" -i emblem-favorite -A default="$S" \
        -A support="$S" -A close="$N" "Second Wind" "$B" 2>/dev/null)
  case "$R" in support|default) xdg-open "$DONATE_URL" & ;; esac
  exit 0
fi

[ -f "$SW_STATE/news-optout" ] && exit 0

DONATE_URL="https://secondwindformac.com/"
[ -f "$SW_STATE/links.conf" ] && . "$SW_STATE/links.conf"
REPO_API="https://api.github.com/repos/secondwindformac/second-wind/releases/latest"

case "${LANG:-en}" in
  es*)
    T_UPD="Hay una versión nueva de Second Wind"; T_UPD_B="Actualizar"
    T_THANKS="Tu Mac lleva un mes y medio de segunda vida 💨 ¿Nos ayudas a revivir un millón más?"
    T_THANKS_BUYER="Gracias por darle una segunda vida a tu Mac 💨 Si quieres, también puedes apoyar el proyecto para revivir un millón más."
    T_SUP="Apoyar"; T_NO="No volver a mostrar" ;;
  *)
    T_UPD="A new Second Wind release is available"; T_UPD_B="Update"
    T_THANKS="Your Mac has enjoyed six weeks of second life 💨 Help us revive a million more?"
    T_THANKS_BUYER="Thanks for giving your Mac a second life 💨 If you'd like, you can also support the project to revive a million more."
    T_SUP="Support"; T_NO="Don't show again" ;;
esac

# (a) Update notice — silent no-op while the repository is private.
# Machines installed from the USB have the real updater, which already shows
# its own "improvement ready" notice with an Update button (Air, 24-Sep: the
# person got both). This one is only for installs the updater does not manage
# (git clones).
case "$(cat "$NEWS/updater" 2>/dev/null)" in
  /usr/local/share/second-wind/*) LATEST="" ;;
  *) LATEST="$(curl -fsSL -m 10 "$REPO_API" 2>/dev/null | grep -m1 '"tag_name"' | cut -d'"' -f4)" ;;
esac
if [ -n "$LATEST" ] && [ "$LATEST" != "$(cat "$NEWS/last-seen-release" 2>/dev/null)" ]; then
  echo "$LATEST" > "$NEWS/last-seen-release"
  R=$(timeout 3600 notify-send -a "Second Wind" -i software-update-available \
        -A default="$T_UPD_B" -A open="$T_UPD_B" "Second Wind" "$T_UPD ($LATEST)" 2>/dev/null)
  [ "$R" = "default" ] && R=open
  # The button opens Second Wind's own updater (what the person wants right
  # then), not a GitHub releases page; the site if the updater is missing.
  if [ "$R" = "open" ]; then
    UPD="$(cat "$NEWS/updater" 2>/dev/null)"
    if [ -f "$UPD" ]; then bash "$UPD" --manual & else xdg-open "https://secondwindformac.com/" & fi
  fi
fi

# (b) One-time support nudge, on day 45 (Air, 25-Sep: on day 30 it landed the
# same day as the end of the Mac Experience trial — two money asks at once).
# Day 45 = 15 days after the trial for people who did not buy; people who
# bought get a thank-you version instead. Only burned once SHOWN.
# `-A default` makes tapping the notice itself = Support: on the Air the CEO
# tapped it and nothing happened (the button hides until the notice is
# expanded). notify-send with buttons waits for an answer: capped at 1 hour,
# a timeout counts as shown (same fix as the Mac Experience notice).
if [ ! -f "$NEWS/nudged" ] && [ -f "$NEWS/install-date" ]; then
  AGE=$(( ( $(date +%s) - $(cat "$NEWS/install-date") ) / 86400 ))
  if [ "$AGE" -ge 45 ]; then
    BODY="$T_THANKS"
    [ "$(cat "$SW_STATE/experience/state" 2>/dev/null)" = active ] && BODY="$T_THANKS_BUYER"
    rc=0
    R=$(timeout 3600 notify-send -a "Second Wind" -i emblem-favorite -A default="$T_SUP" \
          -A support="$T_SUP" -A never="$T_NO" "Second Wind" "$BODY" 2>/dev/null) || rc=$?
    if [ "$rc" -eq 0 ] || [ "$rc" -eq 124 ]; then
      touch "$NEWS/nudged"
      case "$R" in
        support|default) xdg-open "$DONATE_URL" & ;;
        never)           touch "$SW_STATE/news-optout" ;;
      esac
    fi
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
OnCalendar=weekly
RandomizedDelaySec=2h
Persistent=true
[Install]
WantedBy=timers.target
EOF
track_new_file "$UNIT_DIR/second-wind-news.service"
track_new_file "$UNIT_DIR/second-wind-news.timer"

systemctl --user daemon-reload 2>/dev/null || true
systemctl --user enable --now second-wind-news.timer >/dev/null 2>&1 || true
# Machines set up with the old monotonic timer (OnBootSec + OnUnitActiveSec):
# once restarted mid-boot it showed "Trigger: n/a" — never again until a
# reboot, and these Macs mostly just sleep (Air, 25-Sep). Pick up the new one.
systemctl --user restart second-wind-news.timer >/dev/null 2>&1 || true

ok "${MSG[m75_ok]}"
