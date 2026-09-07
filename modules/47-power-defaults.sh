#!/usr/bin/env bash
# 47-power-defaults — sane energy preferences for old laptops with tired
# batteries, extracted from the tuned reference MacBook. Pure user-level
# gsettings (tracked, reversible, no sudo) so it runs in EVERY mode,
# including --no-hardware. The person can change any of it later in
# Settings — these are defaults, not locks.
#
# The heavy lifting (swapfile + hibernation, Mac-style lid behavior) lives
# in 62-power and is NOT touched here. Screen brightness is deliberately
# NOT set: it is per-panel hardware; a copied number could leave another
# screen too dark.

# Plugged in: never auto-suspend. On battery: suspend after 15 minutes.
gset_track org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type "'nothing'"
gset_track org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout "3600"
gset_track org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type "'suspend'"
gset_track org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout "900"

# Dim when idle; power button suspends (Mac habit); low battery switches to
# power-saver by itself; auto brightness only if a sensor exists (harmless
# where there is none). power-saver-profile moved here from 40-panel — it is
# an energy preference, this is its home.
gset_track org.gnome.settings-daemon.plugins.power idle-dim "true"
gset_track org.gnome.settings-daemon.plugins.power power-button-action "'suspend'"
gset_track org.gnome.settings-daemon.plugins.power power-saver-profile-on-low-battery "true"
gset_track org.gnome.settings-daemon.plugins.power ambient-enabled "true"

# Screen off after 5 idle minutes; ask for the password on wake, immediately.
gset_track org.gnome.desktop.session idle-delay "uint32 300"
gset_track org.gnome.desktop.screensaver lock-enabled "true"
gset_track org.gnome.desktop.screensaver lock-delay "uint32 0"

ok "${MSG[m47_ok]}"
