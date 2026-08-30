#!/usr/bin/env bash
# 35-dock — gives the Ubuntu Dock the macOS Dock look: bottom (already),
# floating (not edge-to-edge), 48 px icons, no mounted drives.
# The Ubuntu Dock is reused (same engine as Dash to Dock): fewer moving
# parts, same look.

if [ "${HAVE_DOCK:-0}" != 1 ]; then
  warn "${MSG[m35_no_dock]}"
  return 0
fi

gset_track org.gnome.shell.extensions.dash-to-dock dock-position "'BOTTOM'"
gset_track org.gnome.shell.extensions.dash-to-dock extend-height false
gset_track org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 48
gset_track org.gnome.shell.extensions.dash-to-dock show-mounts false
# The rest already ships right on Ubuntu: bottom position, autohide,
# dot indicators and macOS-like click behavior.
