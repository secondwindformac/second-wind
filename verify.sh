#!/usr/bin/env bash
# MacConLinux — verificación del estado de la instalación.
# Uso: ./verify.sh [--todo | --rapido]
#   --rapido  comprobaciones instantáneas (se usa tras iniciar sesión)
#   --todo    todas, incluidas las que requieren haber cerrado sesión (por defecto)
set -uo pipefail
cd "$(dirname "$0")"
MCL_ROOT="$(pwd)"
source lib/common.sh
source versions.lock

MODE="${1:---todo}"
PASS=0
FAIL=0

chk() {
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then
    PASS=$((PASS + 1)); printf '%s %s\n' "${C_OK}✔${C_OFF}" "$d"
  else
    FAIL=$((FAIL + 1)); printf '%s %s\n' "${C_ERR}✖${C_OFF}" "$d"
  fi
}
eq() { [ "$(gsettings get "$1" "$2" 2>/dev/null)" = "$3" ]; }

echo "— Apariencia —"
chk "Tema de ventanas MacTahoe (solid, menús legibles)" eq org.gnome.desktop.interface gtk-theme "'MacTahoe-Light-solid'"
chk "Iconos MacTahoe"                          eq org.gnome.desktop.interface icon-theme "'MacTahoe'"
chk "Cursor MacTahoe"                          eq org.gnome.desktop.interface cursor-theme "'MacTahoe-cursors'"
chk "Fuente del sistema Inter"                 eq org.gnome.desktop.interface font-name "'Inter 11'"
chk "Tema instalado en ~/.themes"              test -d "$HOME/.themes/MacTahoe-Light-solid/gnome-shell"
chk "Tema derivado MacConLinux (pulidos propios)" test -d "$HOME/.themes/MacConLinux-Light/gnome-shell"
chk "Fuente Inter instalada"                   test -f "$HOME/.local/share/fonts/Inter/Inter-Regular.ttf"
chk "Fondos de pantalla MacTahoe"              test -f "$HOME/.local/share/backgrounds/MacTahoe/MacTahoe-day.jpeg"
chk "Libadwaita (apps modernas) con tema"      test -f "$HOME/.config/gtk-4.0/gtk.css"

echo "— Dock y panel —"
chk "Dock flotante"                            eq org.gnome.shell.extensions.dash-to-dock extend-height "false"
chk "Dock: iconos 48px"                        eq org.gnome.shell.extensions.dash-to-dock dash-max-icon-size "48"
chk "Botones de ventana a la izquierda"        eq org.gnome.desktop.wm.preferences button-layout "'close,minimize,maximize:'"
chk "Esquina activa (Mission Control)"         eq org.gnome.desktop.interface enable-hot-corners "true"
chk "Ventanas nuevas centradas"                eq org.gnome.mutter center-new-windows "true"

echo "— Teclado y Spotlight —"
chk "Sin doble remapeo XKB"                    eq org.gnome.desktop.input-sources xkb-options "@as []"
chk "Cmd+Tab entre apps de todos los escritorios" eq org.gnome.shell.app-switcher current-workspace-only "false"
chk "Cmd+Tab unificado al selector de apps"    bash -c "gsettings get org.gnome.desktop.wm.keybindings switch-applications | grep -q '<Alt>Tab'"
chk "Ahorro de batería automático al quedar poca" eq org.gnome.settings-daemon.plugins.power power-saver-profile-on-low-battery "true"
chk "Servicio de teclado Mac (Toshy) activo"   systemctl --user is-active toshy-config.service
chk "Icono de Toshy oculto"                    bash -c '! test -e "$HOME/.config/autostart/Toshy_Tray.desktop"'
chk "Ulauncher (Spotlight) en ejecución"       pgrep -x ulauncher
chk "Atajo Cmd+Espacio → Spotlight"            bash -c 'gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings | grep -q macconlinux-spotlight'
chk "Vista general liberada del atajo"         eq org.gnome.shell.keybindings toggle-overview "@as []"

if [ "$MODE" = "--todo" ]; then
  echo "— Extensiones (requieren haber cerrado sesión tras instalar) —"
  for uuid in "$EXT_USER_THEME_UUID" "$EXT_BMS_UUID" "$EXT_XREMAP_UUID" "$EXT_LOGO_UUID"; do
    chk "Extensión activa: ${uuid%%@*}" bash -c "LC_ALL=C gnome-extensions info '$uuid' 2>/dev/null | grep -qE 'State: (ACTIVE|ENABLED)'"
  done
  chk "Tema del panel MacConLinux aplicado"    bash -c "[ \"\$(dconf read /org/gnome/shell/extensions/user-theme/name)\" = \"'MacConLinux-Light'\" ]"
  chk "Teclado por aplicación operativo (D-Bus)" busctl --user introspect org.gnome.Shell /com/k0kubun/Xremap

  echo "— Navegadores y pantalla de acceso (si se aplicaron) —"
  if python3 lib/manifest.py has-note "chrome-parchado" 2>/dev/null; then
    chk "Chrome con ventana estilo Mac" bash -c "python3 -c \"import json;d=json.load(open('$HOME/.config/google-chrome/Default/Preferences'));exit(0 if d.get('browser',{}).get('custom_chrome_frame') is False else 1)\""
  else
    echo "  (Chrome aún no vestido — ejecuta ./install.sh --solo navegadores con Chrome cerrado)"
  fi
  if python3 lib/manifest.py has-note "gdm-instalado" 2>/dev/null; then
    chk "Pantalla de acceso con tema Mac (respaldo .bak presente)" test -f "/usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource.bak"
  else
    echo "  (pantalla de acceso aún no aplicada — ./install.sh --solo gdm)"
  fi

  echo "— Hardware (si se instaló ese módulo) —"
  if [ -f /etc/modprobe.d/macconlinux-hid_apple.conf ]; then
    chk "Ventilador inteligente (mbpfan) activo" systemctl is-active mbpfan
    chk "Teclas F persistentes"                  bash -c "grep -q \"fnmode=\$(cat /sys/module/hid_apple/parameters/fnmode)\" /etc/modprobe.d/macconlinux-hid_apple.conf"
    chk "Cámara FaceTime HD (/dev/video0)"       test -e /dev/video0
  else
    echo "  (módulo de hardware no instalado — nada que comprobar)"
  fi
  chk "Gestión térmica del sistema activa"       systemctl is-active thermald
fi

echo
if [ "$FAIL" -eq 0 ]; then
  ok "Resultado: $PASS comprobaciones correctas. ¡Todo en orden!"
else
  warn "Resultado: $PASS correctas, $FAIL con problemas (marcadas con ✖ arriba)."
fi
[ "$FAIL" -eq 0 ]
