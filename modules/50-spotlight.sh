#!/usr/bin/env bash
# 50-spotlight — Cmd+Space search using Ulauncher + our own Spotlight-style
# theme. The key chain (without touching Toshy):
#   physical Cmd+Space → Toshy emits Shift+Ctrl+Space → GNOME runs ulauncher-toggle

if ! command -v ulauncher >/dev/null 2>&1; then
  warn "${MSG[m50_no_ul]}"
  return 0
fi

TDIR="$HOME/.config/ulauncher/user-themes/mactahoe-light"
SJSON="$HOME/.config/ulauncher/settings.json"
AUTOSTART="$HOME/.config/autostart/ulauncher.desktop"

if [ "$DRY_RUN" = 1 ]; then
  info "${MSG[m50_dry]}"
else
  mkdir -p "$HOME/.config/ulauncher/user-themes"
  rsync -a --delete "$SW_ROOT/assets/ulauncher/user-themes/mactahoe-light/" "$TDIR/"
  track_new_file "$TDIR"

  if [ ! -f "$SJSON" ]; then
    cp "$SW_ROOT/assets/ulauncher/settings.json.tpl" "$SJSON"
    track_new_file "$SJSON"
  else
    # A user configuration already exists: only switch the theme.
    python3 - "$SJSON" <<'PY'
import json, sys
p = sys.argv[1]
with open(p) as f:
    d = json.load(f)
d["theme-name"] = "mactahoe-light"
d["show-indicator-icon"] = False
with open(p, "w") as f:
    json.dump(d, f, indent=4)
PY
  fi

  if [ ! -f "$AUTOSTART" ] && [ -f /usr/share/applications/ulauncher.desktop ]; then
    cp /usr/share/applications/ulauncher.desktop "$AUTOSTART"
    track_new_file "$AUTOSTART"
  fi

  # Start it now (under XWayland, as its own .desktop file does)
  if ! pgrep -x ulauncher >/dev/null 2>&1; then
    ( setsid env GDK_BACKEND=x11 ulauncher --hide-window >/dev/null 2>&1 & ) || true
    sleep 2
  fi
fi

# Migration from the pre-rename shortcut id (macconlinux-spotlight)
OLD_KB="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/macconlinux-spotlight/"
if [ "$DRY_RUN" != 1 ] && [ -n "$(dconf read "${OLD_KB}binding" 2>/dev/null)" ]; then
  custom_keybinding_remove macconlinux-spotlight
fi

# Shortcut: free Shift+Ctrl+Space from the overview and give it to Ulauncher
gset_track org.gnome.shell.keybindings toggle-overview "[]"
custom_keybinding_add secondwind-spotlight "Spotlight (Ulauncher)" "ulauncher-toggle" "<Shift><Control>space"

info "${MSG[m50_done]}"
