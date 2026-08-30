#!/usr/bin/env bash
# 65-gdm — pantalla de inicio de sesión con look macOS (tema oficial MacTahoe
# para GDM: fondo estilo macOS + panel oscuro). Requiere sudo.
# Reversible por partida doble: el propio tema respalda el original como .bak,
# y MacConLinux guarda además su propia copia en el respaldo prístino.

YARU_GR="/usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource"

if [ "$DRY_RUN" = 1 ]; then
  info "HARÍA: aplicar el tema macOS a la pantalla de inicio de sesión (con sudo)"
  return 0
fi

if [ ! -f "$YARU_GR" ]; then
  warn "No se encontró el tema de la pantalla de acceso de Ubuntu; se omite."
  return 1
fi

info "Este paso necesita tu contraseña de administrador."
if ! sudo -v; then
  warn "Sin permisos de administrador; la pantalla de acceso queda pendiente (repite con ./install.sh --solo gdm)."
  return 1
fi

# Copia de seguridad propia (además del .bak que crea el tema), solo la 1ª vez
if [ ! -f "$MCL_BACKUP/gnome-shell-theme.gresource.yaru" ]; then
  mkdir -p "$MCL_BACKUP"
  cp "$YARU_GR" "$MCL_BACKUP/gnome-shell-theme.gresource.yaru"
fi

if ( cd "$MCL_CACHE/MacTahoe-gtk-theme" && sudo ./tweaks.sh -g >/dev/null 2>&1 ); then
  mf system-file "$YARU_GR"
  mf note "gdm-instalado"
  ok "Pantalla de inicio de sesión con look macOS (se verá al cerrar sesión o reiniciar)"
else
  warn "El tema de la pantalla de acceso no se pudo aplicar; la original queda intacta."
  return 1
fi
