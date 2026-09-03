#!/usr/bin/env bash
# 65-gdm — macOS-look login screen (official MacTahoe GDM theme: macOS-style
# background + dark panel). Needs sudo.
# Doubly reversible: the theme itself backs the original up as .bak, and
# Second Wind keeps its own extra copy in the pristine backup.

YARU_GR="/usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource"

if [ "$DRY_RUN" = 1 ]; then
  info "${MSG[m65_dry]}"
  return 0
fi

if [ ! -f "$YARU_GR" ]; then
  warn "${MSG[m65_no_yaru]}"
  return 1
fi

info "${MSG[m60_sudo]}"
if ! sw_sudo_ready; then
  warn "${MSG[m65_no_sudo]}"
  return 1
fi

# Our own safety copy (besides the .bak the theme creates), first time only
if [ ! -f "$SW_BACKUP/gnome-shell-theme.gresource.yaru" ]; then
  mkdir -p "$SW_BACKUP"
  cp "$YARU_GR" "$SW_BACKUP/gnome-shell-theme.gresource.yaru"
fi

if ( cd "$SW_CACHE/MacTahoe-gtk-theme" && sudo ./tweaks.sh -g >/dev/null 2>&1 ); then
  mf system-file "$YARU_GR"
  mf note "gdm-installed"
  ok "${MSG[m65_ok]}"
else
  warn "${MSG[m65_fail]}"
  return 1
fi
