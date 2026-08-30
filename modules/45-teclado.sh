#!/usr/bin/env bash
# 45-teclado — teclado estilo Mac.
# Estrategia: Toshy (ya instalado en este equipo) hace el trabajo pesado
# (Cmd+C/V/Q… según cada aplicación). Aquí lo REPARAMOS y lo hacemos INVISIBLE:
#   1. La extensión Xremap (módulo 30) le devuelve la detección de la app activa.
#   2. Quitamos las opciones XKB duplicadas (doble capa de remapeo = teclas locas).
#   3. Ocultamos su icono de bandeja: el usuario no vuelve a ver "Toshy".
# No se toca ni la configuración ni las preferencias internas de Toshy.

if [ "${HAVE_TOSHY:-0}" != 1 ]; then
  warn "Toshy no está instalado en este equipo; el teclado estilo Mac por aplicación queda pendiente (Etapa 1 lo instalará automáticamente)."
  return 0
fi

# 1) Asegurar la extensión que repara los keymaps por aplicación
if [ ! -d "$HOME/.local/share/gnome-shell/extensions/$EXT_XREMAP_UUID" ]; then
  ext_install_pinned "$EXT_XREMAP_UUID" "$EXT_XREMAP_TAG" "$EXT_XREMAP_SHA256" \
    || warn "No se pudo instalar Xremap; los atajos globales funcionan igual, los de por-aplicación quedarán pendientes"
fi

# 2) Una sola capa de remapeo: se limpian las opciones XKB (queda respaldo)
gset_track org.gnome.desktop.input-sources xkb-options "[]"

# 3) Ocultar el icono de bandeja de Toshy (el servicio sigue trabajando de fondo)
TRAY="$HOME/.config/autostart/Toshy_Tray.desktop"
if [ -e "$TRAY" ] || [ -L "$TRAY" ]; then
  if [ "$DRY_RUN" = 1 ]; then
    info "HARÍA: quitar el icono de bandeja de Toshy (su servicio sigue activo)"
  else
    target=""
    [ -L "$TRAY" ] && target="$(readlink -f "$TRAY" 2>/dev/null || true)"
    mf file-removed "$TRAY" "$target"
    rm -f "$TRAY"
  fi
fi
if [ "$DRY_RUN" != 1 ]; then
  pkill -f toshy_tray 2>/dev/null || true
  systemctl --user enable --now toshy-config.service toshy-session-monitor.service >/dev/null 2>&1 || true
fi

info "Teclado Mac: Cmd+C copia, Cmd+V pega, Cmd+Q cierra, Cmd+Tab cambia de app (completo tras cerrar sesión)."
