#!/usr/bin/env bash
# 00-preflight — pre-flight checks. Changes nothing on disk.
# Sourced by install.sh in the main shell: its variables persist.

info "${MSG[pre_checking]}"

[ "$(id -u)" -ne 0 ] || die "${MSG[no_root]}"

. /etc/os-release
[ "${ID:-}" = "ubuntu" ] && [ "${VERSION_ID:-}" = "24.04" ] \
  || die "${MSG[pre_bad_distro]} ${PRETTY_NAME:-unknown})."

gnome-shell --version 2>/dev/null | grep -q ' 46\.' \
  || die "${MSG[pre_need_gnome46]} $(gnome-shell --version 2>/dev/null || echo 'no GNOME'))."

# Active Wayland graphical session for the current user
WAYLAND_OK=0
while read -r sid; do
  [ "$(loginctl show-session "$sid" -p Type --value 2>/dev/null)" = "wayland" ] && WAYLAND_OK=1
done < <(loginctl list-sessions --no-legend 2>/dev/null | awk -v u="$(id -un)" '$3 == u {print $1}')
[ "$WAYLAND_OK" = 1 ] || die "${MSG[pre_need_wayland]}"

for c in curl unzip python3 gsettings dconf gnome-extensions git rsync; do need_cmd "$c"; done

curl -fsI --max-time 10 https://extensions.gnome.org >/dev/null 2>&1 \
  || die "${MSG[pre_no_net]}"

avail_kb="$(df --output=avail "$HOME" | tail -1 | tr -d ' ')"
[ "$avail_kb" -ge $((2 * 1024 * 1024)) ] || die "${MSG[pre_no_space]}"

HAVE_DOCK=0
gsettings list-schemas 2>/dev/null | grep -qx 'org.gnome.shell.extensions.dash-to-dock' && HAVE_DOCK=1
HAVE_TOSHY=0
systemctl --user list-unit-files 'toshy*' 2>/dev/null | grep -q toshy && HAVE_TOSHY=1
export HAVE_DOCK HAVE_TOSHY

SW_MODEL="$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo PC)"
export SW_MODEL
ok "${MSG[pre_ok]} — $SW_MODEL (dock: $HAVE_DOCK, toshy: $HAVE_TOSHY)"
