#!/usr/bin/env bash
# 45-keyboard — Mac-style keyboard.
#
# Cmd+Tab like macOS: switches between APPLICATIONS across ALL workspaces and
# screens (Ubuntu splits Alt+Tab off as "windows of the current workspace",
# and the remapper emits Alt+Tab: both shortcuts are unified into the global
# app switcher).
gset_track org.gnome.desktop.wm.keybindings switch-applications "['<Alt>Tab', '<Super>Tab']"
gset_track org.gnome.desktop.wm.keybindings switch-applications-backward "['<Shift><Alt>Tab', '<Shift><Super>Tab']"
gset_track org.gnome.desktop.wm.keybindings switch-windows "[]"
gset_track org.gnome.desktop.wm.keybindings switch-windows-backward "[]"
gset_track org.gnome.shell.app-switcher current-workspace-only false
gset_track org.gnome.shell.window-switcher current-workspace-only false

# Strategy for the heavy lifting: Toshy (already present on the reference
# machine) provides the per-app behavior (Cmd+C/V/Q… per application). Here we
# REPAIR it and make it INVISIBLE:
#   1. The Xremap extension (module 30) gives it back focused-app detection.
#   2. Duplicate XKB options are cleared (double remapping = crazy keys).
#   3. Its tray icon is hidden: the user never sees the word "Toshy" again.
# Toshy's own config and internal preferences are never touched.

# Re-detect live (module 15 may have just installed Toshy in this same run;
# the preflight value was computed before that).
HAVE_TOSHY_NOW="${HAVE_TOSHY:-0}"
systemctl --user list-unit-files 'toshy*' 2>/dev/null | grep -q toshy && HAVE_TOSHY_NOW=1
if [ "$HAVE_TOSHY_NOW" != 1 ]; then
  warn "${MSG[m45_no_toshy]}"
  return 0
fi

# 1) Make sure the extension that repairs per-app keymaps is present
if [ ! -d "$HOME/.local/share/gnome-shell/extensions/$EXT_XREMAP_UUID" ]; then
  ext_install_pinned "$EXT_XREMAP_UUID" "$EXT_XREMAP_TAG" "$EXT_XREMAP_SHA256" \
    || warn "${MSG[m45_xremap_err]}"
fi

# 2) A single remapping layer: clear XKB options (original value is backed up)
gset_track org.gnome.desktop.input-sources xkb-options "[]"

# 3) Hide Toshy's tray icon (the service keeps working in the background)
TRAY="$HOME/.config/autostart/Toshy_Tray.desktop"
if [ -e "$TRAY" ] || [ -L "$TRAY" ]; then
  if [ "$DRY_RUN" = 1 ]; then
    info "${MSG[m45_tray_dry]}"
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

# 4) ⌘⇧5 like on a Mac: GNOME's capture panel straight in VIDEO mode
# (Ctrl+Shift+Alt+R, no time limit in GNOME 46). Toshy maps ⌘⇧3 (whole
# screen) and ⌘⇧4 (pick an area) Mac-style already, but sends ⌘⇧5 to the
# same panel as ⌘⇧4, in photo mode (CEO, Air 24-Sep). Written inside Toshy's
# own "user_apps" slice — kept across Toshy upgrades, and evaluated before
# Toshy's screenshot keymaps, so it wins. Idempotent (marker lines).
TOSHY_CFG="$HOME/.config/toshy/toshy_config.py"
if [ "$DRY_RUN" != 1 ] && [ -f "$TOSHY_CFG" ] && ! grep -q '# >>> Second Wind: record' "$TOSHY_CFG"; then
  cp "$TOSHY_CFG" "$SW_STATE/toshy_config.before-record.py"
  python3 - "$TOSHY_CFG" <<'PY' && systemctl --user restart toshy-config.service >/dev/null 2>&1 || warn "⌘⇧5 → screen recording: not added"
import sys
p = sys.argv[1]
s = open(p).read()
mark = "###  SLICE_MARK_START: user_apps  ###"
i = s.index(mark)
i = s.index("\n", i) + 1
block = """
# >>> Second Wind: record — ⌘⇧5 opens GNOME's capture panel in video mode
if DESKTOP_ENV == 'gnome':
    keymap("Second Wind: screen recording", {
        C("RC-Shift-Key_5"):        C("C-Shift-Alt-r"),
    }, when = lambda ctx:
        cnfg.screen_has_focus and
        not ctx_app_is_remote
    )
# <<< Second Wind: record
"""
open(p, "w").write(s[:i] + block + s[i:])
PY
fi

info "${MSG[m45_done]}"
