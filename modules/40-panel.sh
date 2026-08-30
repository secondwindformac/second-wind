#!/usr/bin/env bash
# 40-panel — top bar and window behavior, macOS style.

# Hot corner (top-left = overview, like Mission Control)
gset_track org.gnome.desktop.interface enable-hot-corners true
# Window buttons on the left: close, minimize, maximize
gset_track org.gnome.desktop.wm.preferences button-layout "'close,minimize,maximize:'"
# Clock with weekday, like the macOS menu bar
gset_track org.gnome.desktop.interface clock-show-weekday true
# New windows centered
gset_track org.gnome.mutter center-new-windows true
# Battery: automatically switch to power saver when low, like macOS
# (the rest is handled by power-profiles-daemon, thermald and mbpfan —
# TLP is deliberately NOT used: it breaks GNOME's power profile selector)
gset_track org.gnome.settings-daemon.plugins.power power-saver-profile-on-low-battery true
# Note: overlay-key is left empty on purpose (pressing Cmd alone opens
# nothing, just like on a Mac); the overview lives on the hot corner and the
# 3-finger-up gesture.
