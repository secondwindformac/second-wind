#!/usr/bin/env bash
# 15-engines — installs, on clean machines, the engines that later modules
# only configure: Toshy (per-app Mac keyboard), Ulauncher (Spotlight) and the
# Broadcom WiFi driver common on Intel Macs. On machines that already have
# them (like the reference MacBook) this module is a silent no-op and never
# asks for a password. Runs only when the user consented to admin steps.

NEED_WIFI=0
NEED_UL=0
NEED_TOSHY=0
NEED_GIR=0

# Native toolkit bindings for the Second Wind Apps store (GTK4/libadwaita);
# present wherever gnome-tweaks lives, absent on some stock desktops.
python3 -c "import gi; gi.require_version('Adw','1')" 2>/dev/null || NEED_GIR=1

# Broadcom chips that need the proprietary `wl` driver (BCM4360 family, etc.)
# Note: read /proc/modules directly — `lsmod | grep -q` under pipefail gives
# false negatives (grep -q closes the pipe early → SIGPIPE → non-zero).
if lspci -n 2>/dev/null | grep -qE '14e4:(43a0|4331|432b|4353|43a9|43ba)' \
   && ! grep -qE '^(wl|brcmfmac) ' /proc/modules; then
  NEED_WIFI=1
fi
command -v ulauncher >/dev/null 2>&1 || NEED_UL=1
systemctl --user list-unit-files 'toshy*' 2>/dev/null | grep -q toshy || NEED_TOSHY=1

if [ "$NEED_WIFI$NEED_UL$NEED_TOSHY$NEED_GIR" = "0000" ]; then
  ok "${MSG[m15_all_ok]}"
  return 0
fi

if [ "$DRY_RUN" = 1 ]; then
  info "${MSG[m15_dry]}"
  return 0
fi

info "${MSG[m60_sudo]}"
if ! sudo -v; then
  warn "${MSG[m15_no_sudo]}"
  return 1
fi
# Keep sudo warm: a slow Toshy build can outlive the 15-minute timestamp,
# and its internal sudo calls would then stall on a hidden prompt.
( while sleep 50; do sudo -n true 2>/dev/null || exit; done ) &
SW_ENGINES_KEEPALIVE=$!
trap 'kill "$SW_ENGINES_KEEPALIVE" 2>/dev/null || true' EXIT
sudo apt-get update -qq 2>/dev/null || warn "${MSG[m60_apt_warn]}"

# --- WiFi (needs a wired/tethered connection to download the driver) ---
if [ "$NEED_WIFI" = 1 ]; then
  info "${MSG[m15_wifi]}"
  apt_track_install "linux-headers-$(uname -r)" build-essential dkms broadcom-sta-dkms \
    && sudo modprobe wl 2>/dev/null || warn "${MSG[m15_wifi_err]}"
fi

# --- Store toolkit (GTK4/libadwaita python bindings) ---
if [ "$NEED_GIR" = 1 ]; then
  apt_track_install gir1.2-adw-1 python3-gi || true
fi

# --- Ulauncher (Spotlight engine), pinned .deb ---
if [ "$NEED_UL" = 1 ]; then
  info "${MSG[m15_ul]}"
  if download_cached "$ULAUNCHER_DEB_URL" "$SW_CACHE/ulauncher.deb" "$ULAUNCHER_DEB_SHA256" \
     && sudo apt-get install -y "$SW_CACHE/ulauncher.deb" >/dev/null 2>&1; then
    mf apt-installed ulauncher
  else
    warn "${MSG[m15_ul_err]}"
  fi
fi

# --- Toshy (Mac keyboard engine), pinned to the verified commit ---
if [ "$NEED_TOSHY" = 1 ]; then
  info "${MSG[m15_toshy]}"
  # Toshy's installer is interactive BY DESIGN: it resets sudo (sudo -k) and
  # asks its own [y/n] + password on the tty. With a terminal, let it talk to
  # the human (that's the firstboot UX); headless, best-effort with `yes |`.
  TOSHY_RUN() {
    cd "$SW_CACHE/toshy" && export PATH="$HOME/.local/bin:$PATH"
    if ui_has_tty; then
      info "${MSG[m15_toshy_tty]}"
      timeout 900 python3 setup_toshy.py install 2>&1 | tee -a "$SW_LOGDIR/toshy-install.log"
    else
      yes | timeout 900 python3 setup_toshy.py install >>"$SW_LOGDIR/toshy-install.log" 2>&1
    fi
  }
  if clone_pinned "$TOSHY_REPO" "$SW_CACHE/toshy" "$TOSHY_SHA" && ( TOSHY_RUN ); then
    if systemctl --user list-unit-files 'toshy*' 2>/dev/null | grep -q toshy; then
      mf note "toshy-installed-by-secondwind"
      export HAVE_TOSHY=1
      ok "Toshy OK"
    else
      warn "${MSG[m15_toshy_err]}"
    fi
  else
    warn "${MSG[m15_toshy_err]}"
  fi
fi

# --- Hide the engines' technical menu entries from the app grid. The person
# never chose "Toshy" or "Ulauncher" — those names mean nothing to them, and
# the features keep working (Spotlight via ⌘Space, keyboard via services). ---
hide_desktop_entry() {
  local f="$1"
  [ -f "$f" ] || return 0
  if grep -q '^NoDisplay=' "$f"; then
    sed -i 's/^NoDisplay=.*/NoDisplay=true/' "$f"
  else
    printf 'NoDisplay=true\n' >> "$f"
  fi
}
hide_desktop_entry "$HOME/.local/share/applications/app.toshy.preferences.desktop"
hide_desktop_entry "$HOME/.local/share/applications/Toshy_Tray.desktop"
# Ulauncher's entry is system-wide: shadow it with a hidden user-level copy.
if [ -f /usr/share/applications/ulauncher.desktop ] \
   && [ ! -f "$HOME/.local/share/applications/ulauncher.desktop" ]; then
  mkdir -p "$HOME/.local/share/applications"
  cp /usr/share/applications/ulauncher.desktop "$HOME/.local/share/applications/ulauncher.desktop"
  hide_desktop_entry "$HOME/.local/share/applications/ulauncher.desktop"
  track_new_file "$HOME/.local/share/applications/ulauncher.desktop"
fi
ok "${MSG[m15_hidden]}"
