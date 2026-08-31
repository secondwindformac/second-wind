#!/usr/bin/env bash
# 70-apps — installs "Second Wind Apps": the graphical app picker that lives
# in the dock. End users NEVER touch a terminal: they click the store icon,
# tick checkboxes, type their password in the system window — done.
# (The picker itself is apps/second-wind-apps.sh; catalog policy: official
# sources only, web-app windows for apps that do not exist on Linux.)

# The .desktop basename MUST equal the GTK application_id (app.secondwind.Apps)
# or GNOME never associates the running window with the dock favorite (the
# store shows up as a second, generic icon while open).
DESK="$HOME/.local/share/applications/app.secondwind.Apps.desktop"

if [ "$DRY_RUN" = 1 ]; then
  info "${MSG[m70_dry]}"
  return 0
fi

install -d "$SW_SHARE" "$HOME/.local/share/applications"
# Clean the pre-rename spelling so upgrades don't grow a duplicate grid entry
rm -f "$HOME/.local/share/applications/second-wind-apps.desktop"
cp "$SW_ROOT/assets/second-wind-apps.svg" "$SW_SHARE/second-wind-apps.svg"
cat > "$DESK" <<EOF
[Desktop Entry]
Type=Application
Name=${MSG[store_name]}
Comment=${MSG[store_comment]}
Exec=$SW_ROOT/apps/second-wind-apps.py
Icon=$SW_SHARE/second-wind-apps.svg
Terminal=false
Categories=System;Utility;
EOF
track_new_file "$DESK"
track_new_file "$SW_SHARE/second-wind-apps.svg"

# Into the dock, like the App Store on a Mac
favorite_add app.secondwind.Apps.desktop

ok "${MSG[m70_installed]}"
