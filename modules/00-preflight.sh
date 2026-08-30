#!/usr/bin/env bash
# 00-preflight — comprobaciones previas. No cambia nada en disco.
# Se hace `source` desde install.sh en el shell principal: sus variables persisten.

info "Comprobando que este equipo es compatible…"

[ "$(id -u)" -ne 0 ] || die "${MSG[no_root]}"

. /etc/os-release
[ "${ID:-}" = "ubuntu" ] && [ "${VERSION_ID:-}" = "24.04" ] \
  || die "Esta versión de MacConLinux es para Ubuntu 24.04 LTS (detectado: ${PRETTY_NAME:-desconocido})."

gnome-shell --version 2>/dev/null | grep -q ' 46\.' \
  || die "Se necesita GNOME 46 (detectado: $(gnome-shell --version 2>/dev/null || echo 'sin GNOME'))."

# Sesión gráfica Wayland activa del usuario actual
WAYLAND_OK=0
while read -r sid; do
  [ "$(loginctl show-session "$sid" -p Type --value 2>/dev/null)" = "wayland" ] && WAYLAND_OK=1
done < <(loginctl list-sessions --no-legend 2>/dev/null | awk -v u="$(id -un)" '$3 == u {print $1}')
[ "$WAYLAND_OK" = 1 ] || die "No se detectó una sesión gráfica Wayland activa. Inicia sesión en el escritorio y ejecuta de nuevo."

for c in curl unzip python3 gsettings dconf gnome-extensions git rsync; do need_cmd "$c"; done

curl -fsI --max-time 10 https://extensions.gnome.org >/dev/null 2>&1 \
  || die "Sin conexión a internet (no se alcanza extensions.gnome.org). Conéctate y reintenta."

avail_kb="$(df --output=avail "$HOME" | tail -1 | tr -d ' ')"
[ "$avail_kb" -ge $((2 * 1024 * 1024)) ] \
  || die "Se necesitan al menos 2 GB libres en tu carpeta personal."

HAVE_DOCK=0
gsettings list-schemas 2>/dev/null | grep -qx 'org.gnome.shell.extensions.dash-to-dock' && HAVE_DOCK=1
HAVE_TOSHY=0
systemctl --user list-unit-files 'toshy*' 2>/dev/null | grep -q toshy && HAVE_TOSHY=1
export HAVE_DOCK HAVE_TOSHY

ok "Equipo compatible: Ubuntu 24.04, GNOME 46, Wayland, internet OK (dock: $HAVE_DOCK, toshy: $HAVE_TOSHY)"
