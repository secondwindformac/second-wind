#!/usr/bin/env bash
# 15-engines — installs, on clean machines, the engines that later modules
# only configure: Ulauncher (Spotlight) and the Broadcom WiFi driver common
# on Intel Macs. (Toshy moved to 32-toshy: it must run AFTER 30-extensions.) On machines that already have
# them (like the reference MacBook) this module is a silent no-op and never
# asks for a password. Runs only when the user consented to admin steps.

NEED_WIFI=0
NEED_UL=0
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
# Offline-installed Broadcom Macs boot with Second Wind's prebuilt wl (built
# for the ISO kernel only; see usb/drivers/). Once online, hand it over to the
# official DKMS package so future kernel updates keep WiFi working.
NEED_WL_DKMS=0
if [ -f /var/lib/second-wind/wl-preinstalled ] \
   && ! dpkg-query -W -f '${Status}' broadcom-sta-dkms 2>/dev/null | grep -q 'ok installed'; then
  NEED_WL_DKMS=1
fi
command -v ulauncher >/dev/null 2>&1 || NEED_UL=1

# WiFi across kernel updates (Air, 23-Sep: after a security kernel update the
# Mac rebooted into a kernel with no wl, i.e. no WiFi at all). Two layers:
#  - the kernel HEADERS meta-package, so every future kernel arrives with the
#    headers DKMS needs to rebuild wl automatically while it installs;
#  - a boot guard that rebuilds wl offline if a kernel still lacks it.
WL_GUARD=/usr/local/sbin/second-wind-wl-guard
NEED_WL_GUARD=0
if [ -f /etc/modprobe.d/second-wind-wl.conf ] || [ -f /var/lib/second-wind/wl-preinstalled ] \
   || dpkg-query -W -f '${Status}' broadcom-sta-dkms 2>/dev/null | grep -q 'ok installed'; then
  [ -x "$WL_GUARD" ] || NEED_WL_GUARD=1
fi
HDR_META=linux-headers-generic
dpkg-query -W -f '${Status}' linux-image-generic-hwe-24.04 2>/dev/null | grep -q 'ok installed' \
  && HDR_META=linux-headers-generic-hwe-24.04

if [ "$NEED_WIFI$NEED_WL_DKMS$NEED_UL$NEED_GIR$NEED_WL_GUARD" = "00000" ]; then
  ok "${MSG[m15_all_ok]}"
  return 0
fi

if [ "$DRY_RUN" = 1 ]; then
  info "${MSG[m15_dry]}"
  return 0
fi

info "${MSG[m60_sudo]}"
if ! sw_sudo_ready; then
  warn "${MSG[m15_no_sudo]}"
  return 1
fi
# Keep sudo warm: a slow driver build can outlive the 15-minute timestamp,
# and later sudo calls would then stall on a hidden prompt.
( while sleep 50; do sudo -n true 2>/dev/null || exit; done ) &
SW_ENGINES_KEEPALIVE=$!
trap 'kill "$SW_ENGINES_KEEPALIVE" 2>/dev/null || true' EXIT
sudo apt-get update -qq 2>/dev/null || warn "${MSG[m60_apt_warn]}"

# --- WiFi (needs a wired/tethered connection to download the driver) ---
if [ "$NEED_WIFI" = 1 ]; then
  info "${MSG[m15_wifi]}"
  apt_track_install "linux-headers-$(uname -r)" "$HDR_META" build-essential dkms broadcom-sta-dkms \
    && sudo modprobe wl 2>/dev/null || warn "${MSG[m15_wifi_err]}"
  NEED_WL_GUARD=1
fi

# --- WiFi handover: prebuilt wl -> DKMS (keeps working across kernel updates).
# The prebuilt copy is only removed once DKMS has built wl for this kernel, so
# WiFi is never left without a driver.
if [ "$NEED_WL_DKMS" = 1 ]; then
  info "${MSG[m15_wifi_dkms]}"
  if apt_track_install "linux-headers-$(uname -r)" "$HDR_META" build-essential dkms broadcom-sta-dkms \
     && dkms status broadcom-sta 2>/dev/null | grep -q "$(uname -r).*installed"; then
    sudo rm -f "/lib/modules/$(uname -r)/extra/second-wind/wl.ko"
    sudo depmod -a
    # The install held kernel updates only until this handover: lift it.
    sudo apt-mark unhold linux-generic-hwe-24.04 linux-image-generic-hwe-24.04 linux-headers-generic-hwe-24.04 >/dev/null 2>&1 || true
  else
    warn "${MSG[m15_wifi_err]}"
  fi
fi

# --- WiFi boot guard (see NEED_WL_GUARD above) ---
if [ "$NEED_WL_GUARD" = 1 ]; then
  sudo install -D -m 0755 "$SW_ROOT/bin/second-wind-wl-guard" "$WL_GUARD" && mf system-file "$WL_GUARD"
  sudo tee /etc/systemd/system/second-wind-wl-guard.service >/dev/null <<'UNIT'
[Unit]
Description=Second Wind: make sure the Broadcom WiFi driver exists for this kernel
DefaultDependencies=no
After=local-fs.target systemd-modules-load.service
Before=NetworkManager.service network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/second-wind-wl-guard
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
UNIT
  mf system-file /etc/systemd/system/second-wind-wl-guard.service
  sudo systemctl daemon-reload && sudo systemctl enable second-wind-wl-guard.service >/dev/null 2>&1 \
    || warn "WiFi guard could not be enabled"
  # Headers meta for machines installed before 0.9.4 (the Air): future
  # kernels then bring their headers and DKMS rebuilds wl by itself.
  apt_track_install "$HDR_META" || true
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
# (Toshy's own entries are hidden by 32-toshy, right after it installs them.)
# Ulauncher's entry is system-wide: shadow it with a hidden user-level copy.
if [ -f /usr/share/applications/ulauncher.desktop ] \
   && [ ! -f "$HOME/.local/share/applications/ulauncher.desktop" ]; then
  mkdir -p "$HOME/.local/share/applications"
  cp /usr/share/applications/ulauncher.desktop "$HOME/.local/share/applications/ulauncher.desktop"
  hide_desktop_entry "$HOME/.local/share/applications/ulauncher.desktop"
  track_new_file "$HOME/.local/share/applications/ulauncher.desktop"
fi
ok "${MSG[m15_hidden]}"

# Hand the shell back clean: kill our keepalive and release the EXIT trap so
# a later module (32-toshy) can own it.
kill "$SW_ENGINES_KEEPALIVE" 2>/dev/null || true
trap - EXIT
