#!/usr/bin/env bash
# 00-preflight — pre-flight checks. Changes nothing on disk, with ONE exception:
# it installs curl+git if they are missing (see below). Sourced by install.sh in
# the main shell: its variables persist.

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

# curl and git are the ONLY tools Ubuntu Desktop 24.04 does not already ship.
# The offline autoinstall can no longer add them at install time (a Broadcom Mac
# has no internet until its WiFi driver is in place), so install them here — we
# reach this point at firstboot, which has already waited for connectivity
# (phone USB-tether). Everything else in the gate below ships with the desktop.
# Best-effort: if it still fails, the need_cmd gate stops with a clear message
# and firstboot retries on the next login (install.sh is idempotent).
if ! command -v curl >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1; then
  info "${MSG[pre_checking]}"
  sudo apt-get update -qq 2>/dev/null || true
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl git 2>/dev/null || true
fi

for c in curl unzip python3 gsettings dconf gnome-extensions git rsync; do need_cmd "$c"; done

curl -fsI --max-time 10 https://extensions.gnome.org >/dev/null 2>&1 \
  || die "${MSG[pre_no_net]}"

# Clock: an OFFLINE install cannot detect the country, so Ubuntu leaves the
# clock on UTC (seen on the real Air, 23-09: 17:15 shown at 14:15 in Chile).
# Now that we are online, ask Ubuntu's own geolocation service once (with a
# public fallback) and set the
# time zone — only if it is still UTC (never override a zone the person chose).
if [ "$(timedatectl show -p Timezone --value 2>/dev/null)" = "Etc/UTC" ] \
   || [ "$(timedatectl show -p Timezone --value 2>/dev/null)" = "UTC" ]; then
  tz="$(curl -fs --max-time 8 https://geoip.ubuntu.com/lookup 2>/dev/null \
        | sed -n 's|.*<TimeZone>\([^<]*\)</TimeZone>.*|\1|p')"
  # Fallback when Ubuntu's service is down (it returned HTTP 500 on 23-09):
  # a public IP-to-time-zone lookup. Sends only the request itself (no data).
  [ -n "$tz" ] || tz="$(curl -fs --max-time 8 'http://ip-api.com/line/?fields=timezone' 2>/dev/null | head -1)"
  if [ -n "$tz" ] && [ -f "/usr/share/zoneinfo/$tz" ]; then
    sudo timedatectl set-timezone "$tz" 2>/dev/null && info "${MSG[pre_tz]:-Time zone} $tz"
  fi
fi

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
