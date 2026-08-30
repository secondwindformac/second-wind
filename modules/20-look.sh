#!/usr/bin/env bash
# 20-look — MacTahoe theme (GTK + shell), icons, cursors, dynamic day/night
# wallpapers and the Inter font. Everything at user level, no sudo.

info "${MSG[m20_fetch]}"
clone_pinned "$MACTAHOE_GTK_REPO" "$SW_CACHE/MacTahoe-gtk-theme" "$MACTAHOE_GTK_SHA" \
  || die "Could not fetch the MacTahoe theme"
clone_pinned "$MACTAHOE_ICON_REPO" "$SW_CACHE/MacTahoe-icon-theme" "$MACTAHOE_ICON_SHA" \
  || die "Could not fetch the MacTahoe icons"

if [ "$DRY_RUN" = 1 ]; then
  info "${MSG[m20_dry]}"
else
  info "${MSG[m20_theme]}"
  # Note: no --silent-mode (that flag is for root installs only). Both the
  # translucent (normal) and opaque (solid) variants are installed; the SOLID
  # one is applied: GNOME does not blur behind menus, so the translucent
  # variant leaves them nearly unreadable.
  ( cd "$SW_CACHE/MacTahoe-gtk-theme" \
    && ./install.sh -c light -c dark -o normal -o solid --shell >/dev/null 2>&1 ) \
    || warn "${MSG[m20_gtk_err]}"
  # libadwaita link: modern GTK4 apps read the theme from ~/.config/gtk-4.0
  ( cd "$SW_CACHE/MacTahoe-gtk-theme" \
    && ./install.sh -l -c light -o solid >/dev/null 2>&1 ) \
    || warn "${MSG[m20_libadw_err]}"
  mf note "libadwaita-installed"

  # Derived shell theme "SecondWind-*": copy of MacTahoe-*-solid plus our own
  # polish (assets/gnome-shell-overrides.css: continuous macOS-style top bar
  # without per-button pills, solid quick-settings panel). The overrides file
  # carries @PLACEHOLDER@ colors substituted per variant here.
  rm -rf "$HOME/.themes/MacConLinux-Light" "$HOME/.themes/MacConLinux-Dark"   # pre-rename leftovers
  for variant in Light Dark; do
    src="$HOME/.themes/MacTahoe-$variant-solid/gnome-shell"
    if [ -d "$src" ]; then
      if [ "$variant" = "Dark" ]; then
        P_BG='rgba(20, 20, 22, 0.75)';  P_FG='#ffffff'
        P_HOVER='rgba(255, 255, 255, 0.14)'; P_ACTIVE='rgba(255, 255, 255, 0.22)'
        Q_BG='rgba(40, 40, 44, 0.98)';  Q_BORDER='rgba(255, 255, 255, 0.09)'
      else
        P_BG='rgba(247, 247, 249, 0.78)'; P_FG='#1d1d1f'
        P_HOVER='rgba(0, 0, 0, 0.08)';  P_ACTIVE='rgba(0, 0, 0, 0.14)'
        Q_BG='rgba(243, 243, 245, 0.98)'; Q_BORDER='rgba(0, 0, 0, 0.09)'
      fi
      rm -rf "$HOME/.themes/SecondWind-$variant"
      mkdir -p "$HOME/.themes/SecondWind-$variant/gnome-shell"
      cp -a "$src/." "$HOME/.themes/SecondWind-$variant/gnome-shell/"
      sed -e "s|@PANEL_BG@|$P_BG|g" -e "s|@PANEL_FG@|$P_FG|g" \
          -e "s|@PANEL_HOVER@|$P_HOVER|g" -e "s|@PANEL_ACTIVE@|$P_ACTIVE|g" \
          -e "s|@QS_BG@|$Q_BG|g" -e "s|@QS_BORDER@|$Q_BORDER|g" \
          "$SW_ROOT/assets/gnome-shell-overrides.css" \
        >> "$HOME/.themes/SecondWind-$variant/gnome-shell/gnome-shell.css"
      track_new_file "$HOME/.themes/SecondWind-$variant"
    fi
  done

  info "${MSG[m20_wallp]}"
  # Our own copy, WITHOUT deleting the folder first: the theme's helper does
  # rm -rf + copy, and gnome-shell shows a black wallpaper if the file
  # disappears for an instant (the URI does not change, so it never reloads).
  WP_SRC="$SW_CACHE/MacTahoe-gtk-theme/wallpaper"
  BG_DIR="$HOME/.local/share/backgrounds/MacTahoe"
  PROPS_DIR="$HOME/.local/share/gnome-background-properties"
  install -d "$BG_DIR" "$PROPS_DIR"
  cp -f "$WP_SRC/MacTahoe-day.jpeg" "$WP_SRC/MacTahoe-night.jpeg" "$BG_DIR/"
  sed "s|@BACKGROUNDDIR@|$HOME/.local/share/backgrounds|g" "$WP_SRC/MacTahoe.xml" \
    > "$PROPS_DIR/MacTahoe.xml"
  track_new_file "$BG_DIR"
  track_new_file "$PROPS_DIR/MacTahoe.xml"

  info "${MSG[m20_icons]}"
  ( cd "$SW_CACHE/MacTahoe-icon-theme" && ./install.sh >/dev/null 2>&1 )
  ( cd "$SW_CACHE/MacTahoe-icon-theme/cursors" && ./install.sh >/dev/null 2>&1 )
  track_new_file "$HOME/.local/share/icons/MacTahoe"
  track_new_file "$HOME/.local/share/icons/MacTahoe-dark"
  track_new_file "$HOME/.local/share/icons/MacTahoe-cursors"
  track_new_file "$HOME/.local/share/icons/MacTahoe-dark-cursors"

  info "${MSG[m20_font]}"
  if download_cached "$INTER_URL" "$SW_CACHE/Inter-4.1.zip" "$INTER_SHA256"; then
    rm -rf "$SW_CACHE/inter"
    mkdir -p "$SW_CACHE/inter"
    unzip -qo "$SW_CACHE/Inter-4.1.zip" 'extras/ttf/Inter-*' -d "$SW_CACHE/inter"
    install -d "$HOME/.local/share/fonts/Inter"
    for weight in Regular Italic Medium MediumItalic SemiBold SemiBoldItalic Bold BoldItalic; do
      f="$SW_CACHE/inter/extras/ttf/Inter-$weight.ttf"
      [ -f "$f" ] && cp "$f" "$HOME/.local/share/fonts/Inter/"
    done
    fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true
    track_new_file "$HOME/.local/share/fonts/Inter"
  else
    warn "${MSG[m20_font_err]}"
  fi
fi

info "${MSG[m20_apply]}"
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
  # Files were re-copied above; force the shell to reload them (see bg_refresh).
  bg_refresh "file://$BG/MacTahoe-day.jpeg" "file://$BG/MacTahoe-night.jpeg"
fi
