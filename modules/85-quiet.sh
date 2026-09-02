#!/usr/bin/env bash
# 85-quiet — hush the stock Ubuntu first-run pop-ups so the freshly converted
# desktop greets the person as a finished Mac, not a nagging Ubuntu. Everything
# here is USER-LEVEL and reversible (uninstall restores it). Nothing disables
# apt, updates or security — it only stops the auto-pop windows on first login.

if [ "$DRY_RUN" = 1 ]; then
  info "${MSG[m85_dry]}"
  return 0
fi

# 1) GNOME's "Complete your setup" wizard (gnome-initial-setup). Its first-login
# service runs only while ~/.config/gnome-initial-setup-done is absent
# (ConditionPathExists=!…/gnome-initial-setup-done). Create it so the wizard
# never opens over the new Mac desktop.
GIS_DONE="$HOME/.config/gnome-initial-setup-done"
if [ ! -f "$GIS_DONE" ]; then
  mkdir -p "$HOME/.config"
  printf 'yes\n' > "$GIS_DONE"
  track_new_file "$GIS_DONE"
fi

# 2) Ubuntu's "Software Updater" auto-pop (update-notifier). A user-level XDG
# override with Hidden=true shadows the system autostart so it does not launch
# for this user — WITHOUT touching apt or our own weekly updater. The person can
# still update from the store or when Second Wind offers a new version.
UN_SRC="/etc/xdg/autostart/update-notifier.desktop"
UN_OVERRIDE="$HOME/.config/autostart/update-notifier.desktop"
if [ -f "$UN_SRC" ] && [ ! -e "$UN_OVERRIDE" ]; then
  mkdir -p "$HOME/.config/autostart"
  cp "$UN_SRC" "$UN_OVERRIDE"
  if grep -q '^Hidden=' "$UN_OVERRIDE"; then
    sed -i 's/^Hidden=.*/Hidden=true/' "$UN_OVERRIDE"
  else
    printf 'Hidden=true\n' >> "$UN_OVERRIDE"
  fi
  track_new_file "$UN_OVERRIDE"
fi

info "${MSG[m85_ok]}"
