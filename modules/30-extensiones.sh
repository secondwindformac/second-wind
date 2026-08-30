#!/usr/bin/env bash
# 30-extensiones — instala a nivel usuario, desde extensions.gnome.org y con
# versión pineada: User Themes (tema del panel), Blur my Shell (transparencias)
# y Xremap (la pieza que le falta a Toshy para el teclado por aplicación).
# En Wayland las extensiones cargan al cerrar sesión; no se intenta en caliente.

FALLOS=0

ext_install_pinned "$EXT_USER_THEME_UUID" "$EXT_USER_THEME_TAG" "$EXT_USER_THEME_SHA256" \
  || { warn "User Themes no se pudo instalar (el tema del panel quedará pendiente)"; FALLOS=$((FALLOS+1)); }
ext_install_pinned "$EXT_BMS_UUID" "$EXT_BMS_TAG" "$EXT_BMS_SHA256" \
  || { warn "Blur my Shell no se pudo instalar (sin transparencias, no crítico)"; FALLOS=$((FALLOS+1)); }
ext_install_pinned "$EXT_XREMAP_UUID" "$EXT_XREMAP_TAG" "$EXT_XREMAP_SHA256" \
  || { warn "Xremap no se pudo instalar (el teclado por aplicación quedará pendiente)"; FALLOS=$((FALLOS+1)); }

# El tema del panel se deja configurado por adelantado (la extensión lo leerá al
# cargar). Variante solid: menús del panel legibles (ver nota en 20-apariencia).
dconf_track /org/gnome/shell/extensions/user-theme/name "'MacTahoe-Light-solid'"

[ "$FALLOS" -lt 3 ] || return 1
info "Las extensiones quedarán activas al cerrar sesión y volver a entrar."
