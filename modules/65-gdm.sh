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
  # Ubuntu stamps its own logo under the login box through a separate greeter
  # setting (seen on the real Air, 23-09: Mac-style screen + "Ubuntu" logo).
  # Blank it; the original file is backed up and restored by uninstall.
  GREETER=/etc/gdm3/greeter.dconf-defaults
  if [ -f "$GREETER" ] && grep -qE "^[#[:space:]]*logo=" "$GREETER"; then
    [ -f "$SW_BACKUP/greeter.dconf-defaults" ] || cp "$GREETER" "$SW_BACKUP/greeter.dconf-defaults"
    sudo sed -i -E "s|^[#[:space:]]*logo=.*|logo=''|" "$GREETER" && mf system-file "$GREETER"
  fi
  # GDM compiles that file into its dconf database only when the gdm3
  # service starts (ExecStartPre=generate-config), i.e. at boot: on the Air
  # the logo was still there after logging out. `reload` runs the same
  # generate-config now, without touching any open session.
  sudo systemctl reload gdm3 >/dev/null 2>&1 || sudo systemctl reload gdm >/dev/null 2>&1 || true
  ok "${MSG[m65_ok]}"
else
  warn "${MSG[m65_fail]}"
  return 1
fi
