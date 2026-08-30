#!/usr/bin/env bash
# Second Wind Apps — the graphical app picker ("app store", v1).
# Runs from its dock icon: GTK dialogs (zenity), system password window
# (pkexec) — the end user never sees a terminal. Official sources only.
set -uo pipefail
SW_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SW_ROOT"
source lib/common.sh

Z() { zenity --window-icon="$SW_SHARE/second-wind-apps.svg" --title="${MSG[store_name]}" "$@"; }

if ! command -v zenity >/dev/null 2>&1; then
  # Terminal fallback for exotic setups
  exec ./install.sh --only apps
fi

CHOICES="$(Z --list --checklist --width=560 --height=460 \
  --text="${MSG[m70_text]}" \
  --column="" --column=id --column="${MSG[store_col]}" \
  --hide-column=2 --print-column=2 --separator=" " \
  TRUE  quicklook   "${MSG[m70_quicklook]}" \
  TRUE  spotify     "${MSG[m70_spotify]}" \
  TRUE  office      "${MSG[m70_office]}" \
  TRUE  vlc         "${MSG[m70_vlc]}" \
  FALSE zoom        "${MSG[m70_zoom]}" \
  TRUE  wa_web      "${MSG[m70_whatsapp]}" \
  FALSE o365_web    "${MSG[m70_o365]}" \
  FALSE netflix_web "${MSG[m70_netflix]}" )" || exit 0
[ -n "$CHOICES" ] || { Z --info --text="${MSG[m70_none]}" --width=300; exit 0; }

has() { case " $CHOICES " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

APT_PKGS=""
SNAPS=""
has quicklook && APT_PKGS="$APT_PKGS gnome-sushi"
has vlc       && APT_PKGS="$APT_PKGS vlc"
has spotify   && ! snap list spotify >/dev/null 2>&1 && SNAPS="$SNAPS spotify"
has office    && ! snap list onlyoffice-desktopeditors >/dev/null 2>&1 && SNAPS="$SNAPS onlyoffice-desktopeditors"
ZOOM_DEB=""
if has zoom && ! dpkg -s zoom >/dev/null 2>&1; then
  ZOOM_DEB="$SW_CACHE/zoom_amd64.deb"
  curl -fsSL -o "$ZOOM_DEB" https://zoom.us/client/latest/zoom_amd64.deb || ZOOM_DEB=""
fi

FAILED=""
if [ -n "$APT_PKGS$SNAPS$ZOOM_DEB" ]; then
  # One system-authentication window for the whole batch. The command below is
  # built only from fixed tokens above (never from user text).
  PKCMD="set -e; export DEBIAN_FRONTEND=noninteractive; apt-get update -qq || true"
  [ -n "$APT_PKGS" ] && PKCMD="$PKCMD; apt-get install -y$APT_PKGS"
  for s in $SNAPS; do PKCMD="$PKCMD; snap install $s"; done
  [ -n "$ZOOM_DEB" ] && PKCMD="$PKCMD; apt-get install -y '$ZOOM_DEB'"
  (
    echo 10
    pkexec bash -c "$PKCMD" >"$SW_STATE/logs/apps-gui.log" 2>&1
    echo "RC=$?" > "$SW_STATE/logs/apps-gui.rc"
    echo 100
  ) | Z --progress --pulsate --auto-close --no-cancel --text="${MSG[store_working]}" --width=380
  RC="$(sed -n 's/^RC=//p' "$SW_STATE/logs/apps-gui.rc" 2>/dev/null || echo 1)"
  if [ "$RC" != 0 ]; then
    FAILED="${MSG[store_pkfail]}"
  else
    has spotify && mf note "app-spotify"
    has office && mf note "app-onlyoffice"
    has zoom && [ -n "$ZOOM_DEB" ] && mf note "app-zoom"
  fi
fi

# Web apps: own window + dock icon (no password needed)
webapp() {
  local id="$1" name="$2" url="$3" domain="$4"
  local dir="$SW_SHARE/webapps" desk="$HOME/.local/share/applications/secondwind-$id.desktop"
  local browser
  browser="$(command -v google-chrome || command -v google-chrome-stable || true)"
  [ -n "$browser" ] || { FAILED="$FAILED\n${MSG[m70_nochrome]}: $name"; return 0; }
  mkdir -p "$dir" "$HOME/.local/share/applications"
  curl -fsSL -m 10 -o "$dir/$id.png" \
    "https://www.google.com/s2/favicons?domain=$domain&sz=128" 2>/dev/null || true
  local icon="$dir/$id.png"
  [ -s "$icon" ] || icon="web-browser"
  printf '[Desktop Entry]\nType=Application\nName=%s\nExec=%s --app=%s --class=secondwind-%s\nIcon=%s\nStartupWMClass=secondwind-%s\nCategories=Network;\n' \
    "$name" "$browser" "$url" "$id" "$icon" "$id" > "$desk"
  track_new_file "$desk"
}
has wa_web      && webapp whatsapp  "WhatsApp"   "https://web.whatsapp.com" "whatsapp.com"
has o365_web    && webapp office365 "Office 365" "https://www.office.com"   "office.com"
has netflix_web && webapp netflix   "Netflix"    "https://www.netflix.com"  "netflix.com"

if [ -n "$FAILED" ]; then
  Z --warning --width=380 --text="$(printf '%b' "$FAILED")\n\n${MSG[store_partial]}"
else
  Z --info --width=380 --text="${MSG[m70_done]}"
fi
