#!/usr/bin/env bash
# 10-backup — respaldo prístino de la configuración actual. Solo la PRIMERA vez:
# re-ejecutar el instalador nunca pisa el respaldo original.

if [ "$DRY_RUN" = 1 ]; then
  info "HARÍA: respaldo completo de tu configuración en $MCL_BACKUP"
  return 0
fi

if [ -f "$MCL_BACKUP/dconf-full.ini" ]; then
  ok "El respaldo original ya existe (se conserva intacto): $MCL_BACKUP"
else
  info "Guardando un respaldo completo de tu configuración…"
  mkdir -p "$MCL_BACKUP"
  dconf dump / > "$MCL_BACKUP/dconf-full.ini"
  gnome-extensions list > "$MCL_BACKUP/extensiones.txt" 2>/dev/null || true
  apt-mark showmanual > "$MCL_BACKUP/paquetes-manual.txt" 2>/dev/null || true
  dpkg -l > "$MCL_BACKUP/dpkg-l.txt" 2>/dev/null || true
  [ -d "$HOME/.config/gtk-3.0" ] && cp -a "$HOME/.config/gtk-3.0" "$MCL_BACKUP/gtk-3.0"
  [ -d "$HOME/.config/gtk-4.0" ] && cp -a "$HOME/.config/gtk-4.0" "$MCL_BACKUP/gtk-4.0"
  ls -la "$HOME/.config/autostart" > "$MCL_BACKUP/autostart.txt" 2>/dev/null || true
  cat /etc/gdm3/custom.conf > "$MCL_BACKUP/gdm-custom.conf" 2>/dev/null || true
  cat /sys/module/hid_apple/parameters/fnmode > "$MCL_BACKUP/fnmode.txt" 2>/dev/null || true
  {
    for par in \
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
      echo "$par = $(gsettings get $par 2>/dev/null)"
    done
  } > "$MCL_BACKUP/valores-previos.txt"
  ok "Respaldo guardado en $MCL_BACKUP"
fi

mf init
