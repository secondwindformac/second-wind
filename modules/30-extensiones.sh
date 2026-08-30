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
ext_install_pinned "$EXT_LOGO_UUID" "$EXT_LOGO_TAG" "$EXT_LOGO_SHA256" \
  || warn "Logo Menu no se pudo instalar (el menú superior izquierdo quedará pendiente)"

# El tema del panel se deja configurado por adelantado (la extensión lo leerá al
# cargar). Tema derivado MacConLinux = MacTahoe solid + pulidos propios
# (menú rápido con panel sólido legible; ver 20-apariencia).
dconf_track /org/gnome/shell/extensions/user-theme/name "'MacConLinux-Light'"

# Menú superior izquierdo estilo Mac (Logo Menu): icono ⌘ propio (sin marcas
# de Apple), con Acerca de, Ajustes, Bloquear, Apagar…; oculta la píldora de
# Actividades (la vista general queda en la esquina activa y el gesto 3 dedos).
if [ "$DRY_RUN" != 1 ]; then
  install -d "$HOME/.local/share/macconlinux"
  cp "$MCL_ROOT/assets/command-symbolic.svg" "$HOME/.local/share/macconlinux/command-symbolic.svg"
  track_new_file "$HOME/.local/share/macconlinux"
fi
dconf_track /org/gnome/shell/extensions/Logo-menu/use-custom-icon true
dconf_track /org/gnome/shell/extensions/Logo-menu/custom-icon-path "'$HOME/.local/share/macconlinux/command-symbolic.svg'"
dconf_track /org/gnome/shell/extensions/Logo-menu/menu-button-icon-size 18
dconf_track /org/gnome/shell/extensions/Logo-menu/show-power-options true
dconf_track /org/gnome/shell/extensions/Logo-menu/show-lockscreen true
dconf_track /org/gnome/shell/extensions/Logo-menu/hide-softwarecentre true
dconf_track /org/gnome/shell/extensions/Logo-menu/hide-forcequit true
dconf_track /org/gnome/shell/extensions/Logo-menu/show-activities-button false

[ "$FALLOS" -lt 3 ] || return 1
info "Las extensiones quedarán activas al cerrar sesión y volver a entrar."
