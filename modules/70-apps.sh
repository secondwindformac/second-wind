#!/usr/bin/env bash
# 70-apps — curated Mac-style app pack, chosen with checkboxes (no commands).
# Sources policy: only official stores/publishers (snap by the app's own
# publisher, Ubuntu archive, or the vendor's official domain). Apps that do
# not exist on Linux are installed as web apps: their own window + dock icon.
#
# In unattended runs this module only prints a hint; the pack is chosen
# interactively with:  ./install.sh --only apps

if [ "$ASSUME_YES" = 1 ] || ! ui_has_tty || ! command -v whiptail >/dev/null 2>&1; then
  info "${MSG[m70_msg]}"
  return 0
fi

CHOICES=$(whiptail --backtitle "Second Wind" --title "${MSG[m70_title]}" \
  --checklist "${MSG[m70_text]}" 22 74 9 \
  quicklook "${MSG[m70_quicklook]}" ON \
  spotify   "${MSG[m70_spotify]}"   ON \
  office    "${MSG[m70_office]}"    ON \
  vlc       "${MSG[m70_vlc]}"       ON \
  zoom      "${MSG[m70_zoom]}"      OFF \
  wa_web    "${MSG[m70_whatsapp]}"  ON \
  o365_web  "${MSG[m70_o365]}"      OFF \
  netflix_web "${MSG[m70_netflix]}" OFF \
  3>&1 1>&2 2>&3) || { info "${MSG[cancelled]}"; return 0; }

[ -n "$CHOICES" ] || { info "${MSG[m70_none]}"; return 0; }

has() { case " $CHOICES " in *"\"$1\""*) return 0 ;; *) return 1 ;; esac; }

NEED_SUDO=0
for t in quicklook spotify office vlc zoom; do has "$t" && NEED_SUDO=1; done
if [ "$NEED_SUDO" = 1 ]; then
  info "${MSG[m60_sudo]}"
  sudo -v || { warn "${MSG[m70_no_sudo]}"; return 1; }
fi

if has quicklook; then
  info "${MSG[m70_ins]} Quick Look…"
  apt_track_install gnome-sushi && ok "${MSG[m70_ok_quicklook]}" || warn "${MSG[m70_err]} Quick Look"
fi
if has vlc; then
  info "${MSG[m70_ins]} VLC…"
  apt_track_install vlc && ok "VLC ✓" || warn "${MSG[m70_err]} VLC"
fi
if has spotify; then
  info "${MSG[m70_ins]} Spotify…"
  if snap list spotify >/dev/null 2>&1 || sudo snap install spotify >/dev/null 2>&1; then
    mf note "app-spotify"; ok "Spotify ✓"
  else
    warn "${MSG[m70_err]} Spotify"
  fi
fi
if has office; then
  info "${MSG[m70_ins]} OnlyOffice…"
  if snap list onlyoffice-desktopeditors >/dev/null 2>&1 \
     || sudo snap install onlyoffice-desktopeditors >/dev/null 2>&1; then
    mf note "app-onlyoffice"; ok "OnlyOffice ✓"
  else
    warn "${MSG[m70_err]} OnlyOffice"
  fi
fi
if has zoom; then
  info "${MSG[m70_ins]} Zoom…"
  # Official vendor domain; Zoom does not publish stable checksums, so this
  # is the documented exception to pinning (HTTPS + official host only).
  if curl -fsSL -o "$SW_CACHE/zoom_amd64.deb" https://zoom.us/client/latest/zoom_amd64.deb \
     && sudo apt-get install -y "$SW_CACHE/zoom_amd64.deb" >/dev/null 2>&1; then
    mf note "app-zoom"; ok "Zoom ✓"
  else
    warn "${MSG[m70_err]} Zoom"
  fi
fi

# --- Web apps: own window + dock icon (no sudo) ---
webapp() {
  local id="$1" name="$2" url="$3" domain="$4"
  local dir="$SW_SHARE/webapps" desk="$HOME/.local/share/applications/secondwind-$id.desktop"
  local browser
  browser="$(command -v google-chrome || command -v google-chrome-stable || true)"
  [ -n "$browser" ] || { warn "${MSG[m70_nochrome]} ($name)"; return 0; }
  mkdir -p "$dir"
  curl -fsSL -m 10 -o "$dir/$id.png" \
    "https://www.google.com/s2/favicons?domain=$domain&sz=128" 2>/dev/null || true
  local icon="$dir/$id.png"
  [ -s "$icon" ] || icon="web-browser"
  cat > "$desk" <<EOF
[Desktop Entry]
Type=Application
Name=$name
Exec=$browser --app=$url --class=secondwind-$id
Icon=$icon
StartupWMClass=secondwind-$id
Categories=Network;
EOF
  track_new_file "$desk"
  [ -s "$dir/$id.png" ] && track_new_file "$dir/$id.png"
  ok "$name ✓ ${MSG[m70_webapp_ok]}"
}

has wa_web     && webapp whatsapp "WhatsApp"     "https://web.whatsapp.com" "whatsapp.com"
has o365_web   && webapp office365 "Office 365"  "https://www.office.com"   "office.com"
has netflix_web && webapp netflix  "Netflix"     "https://www.netflix.com"  "netflix.com"

info "${MSG[m70_done]}"
