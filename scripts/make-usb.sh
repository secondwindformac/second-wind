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

# Root-only core used by the GUI via pkexec: assumes the seed is staged and
# every confirmation already happened. NO prompts here.
write_core() {
  local DEV="$1"
  [ "$(id -u)" -eq 0 ] || die "--write-core runs as root (pkexec)"
  [ -b "$DEV" ] || die "not a block device: $DEV"
  lsblk -nrpo NAME,MOUNTPOINT "$DEV" | awk '$2 != "" {print $1}' \
    | while read -r p; do umount "$p" || true; done
  dd if="$ISO" of="$DEV" bs=4M conv=fsync status=progress
  sync
  sgdisk -e "$DEV" >/dev/null
  sgdisk -n 0:0:+512MiB -t 0:0700 -c 0:CIDATA "$DEV" >/dev/null
  partprobe "$DEV"; sleep 2
  local PART MNT
  PART="$(lsblk -nrpo NAME "$DEV" | tail -1)"
  mkfs.vfat -n CIDATA "$PART" >/dev/null
  MNT="$(mktemp -d)"
  mount "$PART" "$MNT"
  cp -r "$STAGE"/. "$MNT"/
  sync
  umount "$MNT"; rmdir "$MNT"
  echo "WRITE_CORE_OK"
}

# Zenity GUI: the no-terminal path once launched from its icon.
gui() {
  local Z=(zenity --title "Second Wind USB Creator")
  if [ "${LANG:-en}" != "${LANG#es}" ]; then
    local T_INTRO="Se creará un pendrive que instala la \"Mac nueva\" completa.\n\n• Necesitas un pendrive de 8 GB o más\n• El pendrive se BORRA por completo\n• La primera vez se descargan ~6 GB (Ubuntu oficial verificado)"
    local T_NOUSB="No se detectó ningún pendrive. Conéctalo y vuelve a abrir el creador."
    local T_PICK="Elige el pendrive (se borrará entero):"
    local T_SURE="¿BORRAR COMPLETO este dispositivo y convertirlo en el instalador?\n\n%s\n\nEsta acción no tiene vuelta atrás."
    local T_PREP="Preparando Ubuntu oficial y la semilla (primera vez: varios minutos)…"
    local T_WRITE="Escribiendo el pendrive (varios minutos; no lo desconectes)…"
    local T_DONE="¡Pendrive listo! 🎉\n\nEn el Mac a revivir: enciéndelo manteniendo la tecla Option (⌥), elige \"EFI Boot\" y sigue las 4 pantallas.\n\nGuía completa: docs/es (o pregunta a Claude)."
    local T_FAIL="Algo falló al escribir. Revisa el registro usb-creator.log y reintenta."
  else
    local T_INTRO="This will create a USB stick that installs the full \"new Mac\".\n\n• You need an 8 GB or larger stick\n• The stick is COMPLETELY ERASED\n• First run downloads ~6 GB (verified official Ubuntu)"
    local T_NOUSB="No USB stick detected. Plug one in and open the creator again."
    local T_PICK="Choose the stick (it will be fully erased):"
    local T_SURE="COMPLETELY ERASE this device and turn it into the installer?\n\n%s\n\nThere is no undo."
    local T_PREP="Preparing official Ubuntu and the seed (first time: several minutes)…"
    local T_WRITE="Writing the stick (several minutes; do not unplug)…"
    local T_DONE="USB ready! 🎉\n\nOn the Mac to revive: power it on holding the Option (⌥) key, pick \"EFI Boot\" and follow the 4 screens.\n\nFull guide: docs/ (or ask Claude)."
    local T_FAIL="Something failed while writing. Check usb-creator.log and retry."
  fi

  "${Z[@]}" --info --width 420 --text "$T_INTRO" || exit 0

  mkdir -p "$SW_STATE/logs"
  ( build > "$SW_STATE/logs/usb-creator.log" 2>&1 ) &
  local BPID=$!
  ( while kill -0 $BPID 2>/dev/null; do echo 50; sleep 1; done; echo 100 ) \
    | "${Z[@]}" --progress --pulsate --auto-close --no-cancel --width 420 --text "$T_PREP"
  wait $BPID || { "${Z[@]}" --error --width 380 --text "$T_FAIL"; exit 1; }

  local ROWS DEV
  ROWS="$(lsblk -dnro NAME,SIZE,MODEL,RM | awk '$NF==1 {printf "FALSE\n/dev/%s\n%s — %s\n", $1, $2, ($3=="" ? "USB" : $3)}')"
  [ -n "$ROWS" ] || { "${Z[@]}" --error --width 380 --text "$T_NOUSB"; exit 1; }
  DEV=$(echo "$ROWS" | "${Z[@]}" --list --radiolist --width 480 --height 300 \
        --text "$T_PICK" --column "" --column "Device" --column "Detail") || exit 0
  [ -n "$DEV" ] || exit 0
  local DETAIL
  DETAIL="$(lsblk -dnro SIZE,MODEL "$DEV")"
  # shellcheck disable=SC2059
  "${Z[@]}" --question --default-cancel --width 440 \
    --text "$(printf "$T_SURE" "$DEV — $DETAIL")" || exit 0

  ( pkexec bash "$SW_ROOT/scripts/make-usb.sh" --write-core "$DEV" \
      >> "$SW_STATE/logs/usb-creator.log" 2>&1; echo "RC=$?" > "$SW_STATE/logs/usb-creator.rc" ) &
  local WPID=$!
  ( while kill -0 $WPID 2>/dev/null; do echo 50; sleep 2; done; echo 100 ) \
    | "${Z[@]}" --progress --pulsate --auto-close --no-cancel --width 420 --text "$T_WRITE"
  wait $WPID
  if [ "$(sed -n 's/^RC=//p' "$SW_STATE/logs/usb-creator.rc" 2>/dev/null)" = "0" ]; then
    "${Z[@]}" --info --width 440 --text "$T_DONE"
  else
    "${Z[@]}" --error --width 380 --text "$T_FAIL"
    exit 1
  fi
}

case "${1:-}" in
  --write) shift; [ $# -ge 1 ] || die "--write needs the device (e.g. /dev/sdb)"; build; write_usb "$1" ;;
  --write-core) shift; write_core "$1" ;;
  --gui) gui ;;
  ""|--build) build ;;
  *) die "Unknown option: $1" ;;
esac
