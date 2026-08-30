#!/usr/bin/env bash
# 10-backup — pristine backup of the current settings. FIRST run only:
# re-running the installer never overwrites the original backup.

if [ "$DRY_RUN" = 1 ]; then
  info "${MSG[bk_dry]} $SW_BACKUP"
  return 0
fi

if [ -f "$SW_BACKUP/dconf-full.ini" ]; then
  ok "${MSG[bk_exists]} $SW_BACKUP"
else
  info "${MSG[bk_making]}"
  mkdir -p "$SW_BACKUP"
  dconf dump / > "$SW_BACKUP/dconf-full.ini"
  gnome-extensions list > "$SW_BACKUP/extensions.txt" 2>/dev/null || true
  apt-mark showmanual > "$SW_BACKUP/packages-manual.txt" 2>/dev/null || true
  dpkg -l > "$SW_BACKUP/dpkg-l.txt" 2>/dev/null || true
  [ -d "$HOME/.config/gtk-3.0" ] && cp -a "$HOME/.config/gtk-3.0" "$SW_BACKUP/gtk-3.0"
  [ -d "$HOME/.config/gtk-4.0" ] && cp -a "$HOME/.config/gtk-4.0" "$SW_BACKUP/gtk-4.0"
  ls -la "$HOME/.config/autostart" > "$SW_BACKUP/autostart.txt" 2>/dev/null || true
  cat /etc/gdm3/custom.conf > "$SW_BACKUP/gdm-custom.conf" 2>/dev/null || true
  cat /sys/module/hid_apple/parameters/fnmode > "$SW_BACKUP/fnmode.txt" 2>/dev/null || true
  {
    for pair in \
      "org.gnome.desktop.interface gtk-theme" \
      "org.gnome.desktop.interface icon-theme" \
      "org.gnome.desktop.interface cursor-theme" \
      "org.gnome.desktop.interface color-scheme" \
      "org.gnome.desktop.interface font-name" \
      "org.gnome.desktop.interface enable-hot-corners" \
      "org.gnome.desktop.wm.preferences button-layout" \
      "org.gnome.desktop.input-sources xkb-options" \
      "org.gnome.desktop.background picture-uri" \
      "org.gnome.shell.keybindings toggle-overview" \
      "org.gnome.shell favorite-apps"; do
      # shellcheck disable=SC2086
      echo "$pair = $(gsettings get $pair 2>/dev/null)"
    done
  } > "$SW_BACKUP/previous-values.txt"
  ok "${MSG[bk_done]} $SW_BACKUP"
fi

mf init
