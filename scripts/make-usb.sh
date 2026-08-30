#!/usr/bin/env bash
# Second Wind — USB installer creator ("a new Mac on a USB stick", Stage 2).
#
# Builds a bootable USB from the OFFICIAL Ubuntu Desktop 24.04 ISO (untouched,
# checksum-verified) plus a small seed volume labeled CIDATA carrying the
# autoinstall answers and the Second Wind payload. Booting a Mac from it
# (hold the Option/Alt key at power-on) reinstalls Ubuntu — wiping the disk —
# with only the personal screens asked (language, keyboard, WiFi, user), and
# Second Wind arms itself at first login.
#
# Usage:
#   ./scripts/make-usb.sh                 download/verify ISO + build the seed
#   ./scripts/make-usb.sh --write /dev/sdX   ⚠ write to that USB stick
#                                            (DESTROYS everything on it)
set -Eeuo pipefail
cd "$(dirname "$0")/.."
SW_ROOT="$(pwd)"
source lib/common.sh
source versions.lock

STAGE="$SW_STATE/usb/seed"
ISO="$SW_CACHE/iso/$(basename "$UBUNTU_ISO_URL")"

build() {
  info "Ubuntu ISO: verifying (downloads ~6 GB the first time)…"
  mkdir -p "$(dirname "$ISO")"
  if ! { [ -f "$ISO" ] && printf '%s  %s\n' "$UBUNTU_ISO_SHA256" "$ISO" | sha256sum -c --quiet - 2>/dev/null; }; then
    curl -fL --retry 3 -C - -o "$ISO" "$UBUNTU_ISO_URL"
    printf '%s  %s\n' "$UBUNTU_ISO_SHA256" "$ISO" | sha256sum -c --quiet - \
      || die "ISO checksum mismatch — refusing to use it."
  fi
  ok "ISO OK: $ISO"

  info "Building the seed (autoinstall + Second Wind payload)…"
  rm -rf "$STAGE"
  mkdir -p "$STAGE/firstboot" "$STAGE/autoinstall"
  local HASH
  HASH="$(openssl passwd -6 secondwind)"
  sed "s|@PASSWORD_HASH@|$HASH|" usb/seed/user-data > "$STAGE/user-data"
  cp usb/seed/meta-data "$STAGE/meta-data"
  # Same file where the Desktop installer's folder-scan expects it:
  cp "$STAGE/user-data" "$STAGE/autoinstall/user-data"
  cp usb/firstboot/second-wind-firstboot.sh usb/firstboot/second-wind-firstboot.desktop "$STAGE/firstboot/"
  chmod +x "$STAGE/firstboot/second-wind-firstboot.sh"
  if ! git diff --quiet HEAD 2>/dev/null; then
    warn "Repo has uncommitted changes: the payload is built from the last commit (HEAD)."
  fi
  git archive --prefix=second-wind/ HEAD | gzip > "$STAGE/second-wind.tar.gz"
  ok "Seed ready at $STAGE"
}

write_usb() {
  local DEV="$1"
  [ -b "$DEV" ] || die "$DEV is not a block device (use e.g. /dev/sdb — check with: lsblk -d)"
  local ROOTDISK
  ROOTDISK="/dev/$(lsblk -no PKNAME "$(findmnt -no SOURCE /)" 2>/dev/null || true)"
  [ "$DEV" != "$ROOTDISK" ] || die "$DEV is the system disk — refusing."
  local SIZE MODEL RM
  read -r SIZE RM MODEL <<<"$(lsblk -dnbo SIZE,RM,MODEL "$DEV")"
  [ "$SIZE" -ge $((8 * 1024 * 1024 * 1024)) ] || die "The stick must be at least 8 GB."
  [ "$RM" = "1" ] || warn "$DEV does not report as removable — make VERY sure it is the USB stick."
  echo
  warn "EVERYTHING on $DEV ($(numfmt --to=iec "$SIZE"), ${MODEL:-?}) will be DESTROYED."
  read -r -p "Type exactly 'YES, WIPE' to continue: " ans
  [ "$ans" = "YES, WIPE" ] || die "Cancelled."

  # Unmount anything mounted from the stick
  lsblk -nrpo NAME,MOUNTPOINT "$DEV" | awk '$2 != "" {print $1}' \
    | while read -r p; do sudo umount "$p" || true; done

  info "Writing the official ISO (several minutes)…"
  sudo dd if="$ISO" of="$DEV" bs=4M conv=fsync status=progress
  sync

  info "Adding the CIDATA seed volume…"
  sudo sgdisk -e "$DEV" >/dev/null
  sudo sgdisk -n 0:0:+512MiB -t 0:0700 -c 0:CIDATA "$DEV" >/dev/null
  sudo partprobe "$DEV"; sleep 2
  local PART
  PART="$(lsblk -nrpo NAME "$DEV" | tail -1)"
  sudo mkfs.vfat -n CIDATA "$PART" >/dev/null
  local MNT
  MNT="$(mktemp -d)"
  sudo mount "$PART" "$MNT"
  sudo cp -r "$STAGE"/. "$MNT"/
  sync
  sudo umount "$MNT"
  rmdir "$MNT"

  echo
  ok "USB ready!"
  cat <<'EOF'

  Next, on the Mac to convert:
    1. Plug the stick in, power on HOLDING the Option (⌥/Alt) key.
    2. Pick the orange "EFI Boot" disk.
    3. Choose "Try or Install Ubuntu". The installer asks only language,
       keyboard, network and your name/password — then it WIPES the disk
       and installs by itself (☕ ~20-30 min).
    4. At first login, follow the Second Wind window (one confirmation +
       your password). Tip: if the Mac's WiFi needs a driver, share your
       phone's internet over USB cable for a few minutes.
EOF
}

case "${1:-}" in
  --write) shift; [ $# -ge 1 ] || die "--write needs the device (e.g. /dev/sdb)"; build; write_usb "$1" ;;
  ""|--build) build ;;
  *) die "Unknown option: $1" ;;
esac
