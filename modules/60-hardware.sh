#!/usr/bin/env bash
# 60-hardware — hardware fixes for Intel MacBooks. Needs sudo.
#   1. mbpfan: smart fan control (Macs on Linux tend to idle the fan even
#      with a hot CPU).
#   2. Persist the Apple keyboard F-key mode (hid_apple fnmode).
#   3. FaceTime HD camera: third-party DKMS driver + firmware extracted from
#      Apple's own update package, locally. Full rollback: if it does not
#      build for this kernel, everything camera-related is cleaned up and the
#      rest of the install is unaffected.
#   4. Optional: disable autologin so the keyring stops nagging.

if [ "$DRY_RUN" = 1 ]; then
  info "${MSG[m60_dry]}"
  return 0
fi

info "${MSG[m60_sudo]}"
if ! sudo -v; then
  warn "${MSG[m60_no_sudo]}"
  return 1
fi
# Keep sudo alive while the module runs
( while sleep 50; do sudo -n true 2>/dev/null || exit; done ) &
SW_SUDO_KEEPALIVE=$!
trap 'kill "$SW_SUDO_KEEPALIVE" 2>/dev/null || true' EXIT

# Install a package only if missing, recording it for uninstall.
apt_track_install() {
  local p
  for p in "$@"; do
    dpkg -s "$p" >/dev/null 2>&1 && continue
    if sudo apt-get install -y "$p" >/dev/null 2>&1; then
      mf apt-installed "$p"
    else
      warn "Could not install package $p"
      return 1
    fi
  done
}

sudo apt-get update -qq 2>/dev/null || warn "${MSG[m60_apt_warn]}"

# --- 1) Fan ---
info "${MSG[m60_fan]}"
if apt_track_install mbpfan; then
  sudo systemctl enable --now mbpfan >/dev/null 2>&1 \
    && ok "${MSG[m60_fan_ok]}" \
    || warn "${MSG[m60_fan_err1]}"
else
  warn "${MSG[m60_fan_err2]}"
fi

# --- 1b) Hardware video decoding (VA-API driver for old Intel GPUs) ---
# Pairs with the Chrome launcher flags from module 55: H.264 video decodes on
# the GPU instead of the CPU → far less heat and fan noise on video playback.
info "${MSG[m60_va]}"
apt_track_install i965-va-driver vainfo || warn "${MSG[m60_va_err]}"

# --- 2) Persistent F-keys ---
FN="$(cat /sys/module/hid_apple/parameters/fnmode 2>/dev/null || echo 3)"
CONF=/etc/modprobe.d/secondwind-hid_apple.conf
OLD_CONF=/etc/modprobe.d/macconlinux-hid_apple.conf
if [ -f "$OLD_CONF" ] && [ ! -f "$CONF" ]; then
  sudo mv "$OLD_CONF" "$CONF"    # pre-rename migration
  mf system-file "$CONF"
fi
if [ ! -f "$CONF" ]; then
  info "${MSG[m60_fn]}"
  sed "s/@FNMODE@/$FN/" "$SW_ROOT/assets/modprobe/secondwind-hid_apple.conf.tpl" \
    | sudo tee "$CONF" >/dev/null
  mf system-file "$CONF"
  sudo update-initramfs -u >/dev/null 2>&1 || warn "${MSG[m60_initramfs_warn]}"
fi

# --- 3) FaceTime HD camera ---
if [ -e /dev/video0 ]; then
  ok "${MSG[m60_cam_already]}"
else
  info "${MSG[m60_cam_prep]}"
  if apt_track_install "linux-headers-$(uname -r)" build-essential dkms; then
    CAM_OK=0
    if clone_pinned "$FTHD_FW_REPO" "$SW_CACHE/facetimehd-firmware" "$FTHD_FW_SHA" \
       && clone_pinned "$FTHD_REPO" "$SW_CACHE/facetimehd" "$FTHD_SHA"; then

      # Firmware: extracted locally from an official Apple package (never redistributed)
      if ( cd "$SW_CACHE/facetimehd-firmware" && make >/dev/null 2>&1 \
           && sudo make install >/dev/null 2>&1 ); then
        mf system-file /usr/lib/firmware/facetimehd/firmware.bin

        # Driver via DKMS (rebuilds itself with every new kernel)
        VER="0.1"
        [ -f "$SW_CACHE/facetimehd/dkms.conf" ] \
          && VER="$(sed -n 's/^PACKAGE_VERSION="\?\([^"]*\)"\?/\1/p' "$SW_CACHE/facetimehd/dkms.conf" | head -1)"
        [ -n "$VER" ] || VER="0.1"
        SRC="/usr/src/facetimehd-$VER"
        sudo rsync -a --delete --exclude=.git "$SW_CACHE/facetimehd/" "$SRC/"
        if [ ! -f "$SRC/dkms.conf" ]; then
          printf 'PACKAGE_NAME="facetimehd"\nPACKAGE_VERSION="%s"\nBUILT_MODULE_NAME[0]="facetimehd"\nDEST_MODULE_LOCATION[0]="/extra"\nAUTOINSTALL="yes"\nMAKE[0]="make KDIR=/lib/modules/${kernelver}/build"\nCLEAN="make clean"\n' "$VER" \
            | sudo tee "$SRC/dkms.conf" >/dev/null
        fi
        sudo dkms add -m facetimehd -v "$VER" >/dev/null 2>&1 || true
        if sudo dkms build -m facetimehd -v "$VER" >/dev/null 2>&1 \
           && sudo dkms install -m facetimehd -v "$VER" >/dev/null 2>&1; then
          sudo modprobe facetimehd 2>/dev/null || true
          sleep 2
          mf dkms-installed "facetimehd/$VER"
          if [ -e /dev/video0 ]; then
            ok "${MSG[m60_cam_ok]}"
          else
            warn "${MSG[m60_cam_reboot]}"
          fi
          CAM_OK=1
        else
          warn "${MSG[m60_cam_fail]}"
          sudo dkms remove -m facetimehd -v "$VER" --all >/dev/null 2>&1 || true
          sudo rm -rf "$SRC"
        fi
      else
        warn "${MSG[m60_fw_fail]}"
      fi
    else
      warn "${MSG[m60_src_fail]}"
    fi
    [ "$CAM_OK" = 1 ] || mf note "camera-pending"
  else
    warn "${MSG[m60_tools_fail]}"
  fi
fi

# --- 4) Autologin / keyring (asked only interactively, when autologin is on) ---
if [ "$ASSUME_YES" != 1 ] && ui_has_tty \
   && grep -q '^AutomaticLoginEnable\s*=\s*[Tt]rue' /etc/gdm3/custom.conf 2>/dev/null; then
  if ui_yesno "${MSG[ask_autologin]}" --default-no; then
    sudo sed -i 's/^\(AutomaticLoginEnable\s*=\s*\)[Tt]rue/\1false/' /etc/gdm3/custom.conf
    mf system-file /etc/gdm3/custom.conf
    ok "${MSG[m60_autologin_ok]}"
  fi
fi

kill "$SW_SUDO_KEEPALIVE" 2>/dev/null || true
trap - EXIT
