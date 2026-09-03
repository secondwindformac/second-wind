#!/usr/bin/env bash
# 62-power — battery care for old laptops. Needs sudo.
#
# Implements macOS-like standby behavior via systemd suspend-then-hibernate:
#   • Close the lid → normal suspend (instant resume).
#   • Still closed after 2 hours → the machine wakes briefly and HIBERNATES:
#     the session is saved to disk and power drain drops to ZERO. Opening the
#     lid boots straight back into the saved session.
# This is the user's "power off after a couple of hours" idea, minus the
# downside (a plain shutdown would lose the session).
#
# Pieces: swap file large enough to fit RAM, resume location registered in
# GRUB + initramfs, and systemd sleep/lid policies. All tracked and reversible.

if [ "$DRY_RUN" = 1 ]; then
  info "${MSG[m62_dry]}"
  return 0
fi

# Kernel hibernate support (no Secure Boot lockdown on these Macs)
if ! grep -qE 'platform|shutdown' /sys/power/disk 2>/dev/null; then
  warn "${MSG[m62_no_hib]}"
  return 1
fi

info "${MSG[m60_sudo]}"
if ! sw_sudo_ready; then
  warn "${MSG[m62_no_sudo]}"
  return 1
fi

SWAPFILE=/swap.img
MEM_KB="$(awk '/^MemTotal:/{print $2}' /proc/meminfo)"
TARGET_GIB=$(( MEM_KB / 1048576 + 2 ))                       # RAM rounded up + margin
CUR_BYTES="$(stat -c %s "$SWAPFILE" 2>/dev/null || echo 0)"
TARGET_BYTES=$(( TARGET_GIB * 1073741824 ))

# --- 1) Swap file big enough to hold RAM ---
if [ "$CUR_BYTES" -lt "$TARGET_BYTES" ]; then
  SWAP_USED_KB="$(awk '/^SwapTotal:/{t=$2} /^SwapFree:/{f=$2} END{print t-f}' /proc/meminfo)"
  MEM_AVAIL_KB="$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)"
  if [ "$MEM_AVAIL_KB" -lt $(( SWAP_USED_KB + 524288 )) ]; then
    warn "${MSG[m62_swap_busy]}"
    return 1
  fi
  info "${MSG[m62_swap]}"
  [ -f "$SW_BACKUP/swap-original-bytes" ] || echo "$CUR_BYTES" > "$SW_BACKUP/swap-original-bytes"
  sudo swapoff "$SWAPFILE" 2>/dev/null || true
  sudo fallocate -l "${TARGET_GIB}G" "$SWAPFILE"
  sudo chmod 600 "$SWAPFILE"
  sudo mkswap "$SWAPFILE" >/dev/null
  sudo swapon "$SWAPFILE"
  mf note "swap-resized"
fi

# --- 2) Resume location (root UUID + physical offset of the swap file) ---
info "${MSG[m62_grub]}"
ROOT_UUID="$(findmnt -no UUID /)"
OFFSET="$(sudo filefrag -v "$SWAPFILE" | awk '$1=="0:" {gsub(/[.:]/,"",$4); print $4; exit}')"
if [ -z "$ROOT_UUID" ] || [ -z "$OFFSET" ]; then
  warn "${MSG[m62_fail]}"
  return 1
fi

GRUB_D=/etc/default/grub.d/secondwind-hibernate.cfg
printf 'GRUB_CMDLINE_LINUX_DEFAULT="$GRUB_CMDLINE_LINUX_DEFAULT resume=UUID=%s resume_offset=%s"\n' \
  "$ROOT_UUID" "$OFFSET" | sudo tee "$GRUB_D" >/dev/null
mf system-file "$GRUB_D"

INITRD_CONF=/etc/initramfs-tools/conf.d/secondwind-resume
printf 'RESUME=UUID=%s\n' "$ROOT_UUID" | sudo tee "$INITRD_CONF" >/dev/null
mf system-file "$INITRD_CONF"

sudo update-grub >/dev/null 2>&1 || warn "update-grub failed (check the log)"
sudo update-initramfs -u >/dev/null 2>&1 || warn "${MSG[m60_initramfs_warn]}"

# --- 3) Sleep and lid policies ---
sudo install -d /etc/systemd/sleep.conf.d /etc/systemd/logind.conf.d
printf '[Sleep]\nAllowSuspendThenHibernate=yes\nHibernateDelaySec=7200\n' \
  | sudo tee /etc/systemd/sleep.conf.d/secondwind.conf >/dev/null
mf system-file /etc/systemd/sleep.conf.d/secondwind.conf
# On battery: suspend, then hibernate. On AC: plain suspend (no battery at risk).
printf '[Login]\nHandleLidSwitch=suspend-then-hibernate\nHandleLidSwitchExternalPower=suspend\nHandleLidSwitchDocked=ignore\n' \
  | sudo tee /etc/systemd/logind.conf.d/secondwind.conf >/dev/null
mf system-file /etc/systemd/logind.conf.d/secondwind.conf
sudo systemctl kill -sHUP systemd-logind 2>/dev/null || true

info "${MSG[m62_lid]}"
ok "${MSG[m62_ok]}"
