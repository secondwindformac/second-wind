#!/usr/bin/env bash
# 30-extensions — user-level installs, from extensions.gnome.org, version-pinned:
# User Themes (panel theme), Blur my Shell (blur), Xremap (the missing piece
# that gives Toshy its per-app keyboard back) and Logo Menu (Mac-style top-left
# menu). On Wayland extensions load at next login; no hot-loading is attempted.

FAILURES=0

ext_install_pinned "$EXT_USER_THEME_UUID" "$EXT_USER_THEME_TAG" "$EXT_USER_THEME_SHA256" \
  || { warn "${MSG[m30_ut_err]}"; FAILURES=$((FAILURES+1)); }
ext_install_pinned "$EXT_BMS_UUID" "$EXT_BMS_TAG" "$EXT_BMS_SHA256" \
  || { warn "${MSG[m30_bms_err]}"; FAILURES=$((FAILURES+1)); }
ext_install_pinned "$EXT_XREMAP_UUID" "$EXT_XREMAP_TAG" "$EXT_XREMAP_SHA256" \
  || { warn "${MSG[m30_xr_err]}"; FAILURES=$((FAILURES+1)); }
ext_install_pinned "$EXT_LOGO_UUID" "$EXT_LOGO_TAG" "$EXT_LOGO_SHA256" \
  || warn "${MSG[m30_logo_err]}"

# Our own top-bar extension (assets/shell-extension): clock on the right, the
# active app's name, a search button and notifications top-right, like the
# Mac menu bar (CEO comparison M2 vs Air, 23-Sep). Shipped in the repo, so no
# download and nothing to pin.
SW_PANEL_UUID="secondwind-panel@secondwindformac.com"
if [ "$DRY_RUN" != 1 ]; then
  install -d "$SW_CACHE"
  ( cd "$SW_ROOT/assets/shell-extension/$SW_PANEL_UUID" && \
    python3 -c 'import sys,zipfile,os; z=zipfile.ZipFile(sys.argv[1],"w"); [z.write(f) for f in sorted(os.listdir(".")) if os.path.isfile(f)]' \
      "$SW_CACHE/$SW_PANEL_UUID.zip" ) \
    && gnome-extensions install --force "$SW_CACHE/$SW_PANEL_UUID.zip" \
    && mf ext-installed "$SW_PANEL_UUID" && enable_extension "$SW_PANEL_UUID" \
    || warn "Second Wind panel extension could not be installed"
fi

# Panel theme, pre-configured (the extension reads it when it loads).
# SecondWind derived theme = MacTahoe solid + our polish (see 20-look).
dconf_track /org/gnome/shell/extensions/user-theme/name "'SecondWind-$SW_SHELL_VARIANT'"

# Mac-style top-left menu (Logo Menu): our own ⌘ (Command, U+2318) mark — the
# Second Wind brand symbol (same one on the site and favicon). ⌘ is a
# generic Unicode "place of interest" glyph, NOT an Apple trademark; the APPLE
# logo IS, and it is this extension's built-in DEFAULT. So we (a) force our own
# custom icon and (b) keep use-custom-icon true so it can NEVER fall back to
# Apple. (That fallback only ever appeared when the custom icon failed to apply
# in a stale shell; the firstboot reboot makes it apply reliably.) The icon
# matches the bar: white strokes on the dark bar, dark on the light one.
# White ⌘ in both variants: the bar is dark either way (see 20-look).
LOGO_ICON="command-symbolic-white.svg"
if [ "$DRY_RUN" != 1 ]; then
  install -d "$SW_SHARE"
  cp "$SW_ROOT/assets/command-symbolic.svg" "$SW_ROOT/assets/command-symbolic-white.svg" "$SW_SHARE/"
  track_new_file "$SW_SHARE"
fi
dconf_track /org/gnome/shell/extensions/Logo-menu/use-custom-icon true
dconf_track /org/gnome/shell/extensions/Logo-menu/custom-icon-path "'$SW_SHARE/$LOGO_ICON'"
dconf_track /org/gnome/shell/extensions/Logo-menu/menu-button-icon-size 18
dconf_track /org/gnome/shell/extensions/Logo-menu/show-power-options true
dconf_track /org/gnome/shell/extensions/Logo-menu/show-lockscreen true
dconf_track /org/gnome/shell/extensions/Logo-menu/hide-softwarecentre true
dconf_track /org/gnome/shell/extensions/Logo-menu/hide-forcequit true
dconf_track /org/gnome/shell/extensions/Logo-menu/show-activities-button false

[ "$FAILURES" -lt 3 ] || return 1
info "${MSG[m30_relogin]}"
