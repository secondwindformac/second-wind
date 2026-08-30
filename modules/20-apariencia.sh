#!/usr/bin/env bash
# 20-apariencia — tema MacTahoe (GTK + shell), iconos, cursores, wallpapers
# dinámicos día/noche y fuente Inter. Todo a nivel de usuario, sin sudo.

info "Descargando los temas (versiones verificadas)…"
clone_pinned "$MACTAHOE_GTK_REPO" "$MCL_CACHE/MacTahoe-gtk-theme" "$MACTAHOE_GTK_SHA" \
  || die "No se pudo obtener el tema MacTahoe"
clone_pinned "$MACTAHOE_ICON_REPO" "$MCL_CACHE/MacTahoe-icon-theme" "$MACTAHOE_ICON_SHA" \
  || die "No se pudieron obtener los iconos MacTahoe"

if [ "$DRY_RUN" = 1 ]; then
  info "HARÍA: instalar tema GTK+shell MacTahoe (claro y oscuro), iconos, cursores, fondos de pantalla y fuente Inter"
else
  info "Instalando tema de ventanas y paneles (esto tarda 1-2 minutos)…"
  # Nota: sin --silent-mode (ese flag es solo para instalaciones como root).
  # Se instalan las variantes translúcida (normal) y opaca (solid); se APLICA la
  # solid: GNOME no desenfoca lo que hay detrás de los menús, así que la
  # translúcida deja los menús casi ilegibles.
  ( cd "$MCL_CACHE/MacTahoe-gtk-theme" \
    && ./install.sh -c light -c dark -o normal -o solid --shell >/dev/null 2>&1 ) \
    || warn "El instalador del tema GTK devolvió un error; se continúa (revisa el registro)"
  # Vínculo libadwaita: apps GTK4 modernas toman el tema desde ~/.config/gtk-4.0
  ( cd "$MCL_CACHE/MacTahoe-gtk-theme" \
    && ./install.sh -l -c light -o solid >/dev/null 2>&1 ) \
    || warn "No se pudo crear el vínculo libadwaita"
  mf note "libadwaita-instalado"

  # Tema derivado "MacConLinux-*": copia de MacTahoe-*-solid + pulidos propios
  # (assets/gnome-shell-overrides.css: menú rápido con panel sólido, sombras).
  for variante in Light Dark; do
    SRCT="$HOME/.themes/MacTahoe-$variante-solid/gnome-shell"
    if [ -d "$SRCT" ]; then
      rm -rf "$HOME/.themes/MacConLinux-$variante"
      mkdir -p "$HOME/.themes/MacConLinux-$variante/gnome-shell"
      cp -a "$SRCT/." "$HOME/.themes/MacConLinux-$variante/gnome-shell/"
      cat "$MCL_ROOT/assets/gnome-shell-overrides.css" \
        >> "$HOME/.themes/MacConLinux-$variante/gnome-shell/gnome-shell.css"
      track_new_file "$HOME/.themes/MacConLinux-$variante"
    fi
  done

  info "Instalando fondos de pantalla dinámicos (día/noche)…"
  ( cd "$MCL_CACHE/MacTahoe-gtk-theme" \
    && bash wallpaper/install-gnome-backgrounds.sh >/dev/null 2>&1 )
  track_new_file "$HOME/.local/share/backgrounds/MacTahoe"
  track_new_file "$HOME/.local/share/gnome-background-properties/MacTahoe.xml"

  info "Instalando iconos y cursores (esto es lo más lento, 2-4 minutos)…"
  ( cd "$MCL_CACHE/MacTahoe-icon-theme" && ./install.sh >/dev/null 2>&1 )
  ( cd "$MCL_CACHE/MacTahoe-icon-theme/cursors" && ./install.sh >/dev/null 2>&1 )
  track_new_file "$HOME/.local/share/icons/MacTahoe"
  track_new_file "$HOME/.local/share/icons/MacTahoe-dark"
  track_new_file "$HOME/.local/share/icons/MacTahoe-cursors"
  track_new_file "$HOME/.local/share/icons/MacTahoe-dark-cursors"

  info "Instalando la fuente Inter…"
  if download_cached "$INTER_URL" "$MCL_CACHE/Inter-4.1.zip" "$INTER_SHA256"; then
    rm -rf "$MCL_CACHE/inter"
    mkdir -p "$MCL_CACHE/inter"
    unzip -qo "$MCL_CACHE/Inter-4.1.zip" 'extras/ttf/Inter-*' -d "$MCL_CACHE/inter"
    install -d "$HOME/.local/share/fonts/Inter"
    for peso in Regular Italic Medium MediumItalic SemiBold SemiBoldItalic Bold BoldItalic; do
      f="$MCL_CACHE/inter/extras/ttf/Inter-$peso.ttf"
      [ -f "$f" ] && cp "$f" "$HOME/.local/share/fonts/Inter/"
    done
    fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true
    track_new_file "$HOME/.local/share/fonts/Inter"
  else
    warn "No se pudo descargar Inter; se mantienen las fuentes actuales"
  fi
fi

info "Aplicando la apariencia…"
gset_track org.gnome.desktop.interface gtk-theme "'MacTahoe-Light-solid'"
gset_track org.gnome.desktop.interface icon-theme "'MacTahoe'"
gset_track org.gnome.desktop.interface cursor-theme "'MacTahoe-cursors'"
gset_track org.gnome.desktop.interface color-scheme "'default'"
if [ "$DRY_RUN" = 1 ] || [ -f "$HOME/.local/share/fonts/Inter/Inter-Regular.ttf" ]; then
  gset_track org.gnome.desktop.interface font-name "'Inter 11'"
  gset_track org.gnome.desktop.interface document-font-name "'Inter 11'"
  gset_track org.gnome.desktop.wm.preferences titlebar-font "'Inter Bold 11'"
fi
gset_track org.gnome.desktop.interface font-antialiasing "'grayscale'"
gset_track org.gnome.desktop.interface font-hinting "'slight'"

BG="$HOME/.local/share/backgrounds/MacTahoe"
if [ "$DRY_RUN" = 1 ] || [ -f "$BG/MacTahoe-day.jpeg" ]; then
  gset_track org.gnome.desktop.background picture-uri "'file://$BG/MacTahoe-day.jpeg'"
  gset_track org.gnome.desktop.background picture-uri-dark "'file://$BG/MacTahoe-night.jpeg'"
  gset_track org.gnome.desktop.background picture-options "'zoom'"
  gset_track org.gnome.desktop.screensaver picture-uri "'file://$BG/MacTahoe-day.jpeg'"
fi
