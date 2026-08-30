#!/usr/bin/env bash
# 70-apps — installs "Second Wind Apps": the graphical app picker that lives
# in the dock. End users NEVER touch a terminal: they click the store icon,
# tick checkboxes, type their password in the system window — done.
# (The picker itself is apps/second-wind-apps.sh; catalog policy: official
# sources only, web-app windows for apps that do not exist on Linux.)

DESK="$HOME/.local/share/applications/second-wind-apps.desktop"

if [ "$DRY_RUN" = 1 ]; then
  info "${MSG[m70_dry]}"
  return 0
fi

install -d "$SW_SHARE" "$HOME/.local/share/applications"
cp "$SW_ROOT/assets/second-wind-apps.svg" "$SW_SHARE/second-wind-apps.svg"
cat > "$DESK" <<EOF
[Desktop Entry]
Type=Application
Name=${MSG[store_name]}
Comment=${MSG[store_comment]}
Exec=$SW_ROOT/apps/second-wind-apps.sh
Icon=$SW_SHARE/second-wind-apps.svg
Terminal=false
Categories=System;Utility;
EOF
track_new_file "$DESK"
track_new_file "$SW_SHARE/second-wind-apps.svg"

# Into the dock, like the App Store on a Mac
favorite_add second-wind-apps.desktop

ok "${MSG[m70_installed]}"
