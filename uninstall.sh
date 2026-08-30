#!/usr/bin/env bash
# Second Wind — uninstaller. Restores Ubuntu's original configuration using
# the change manifest and the pristine backup.
# Usage: ./uninstall.sh [--yes] [--purge-themes] [--full-dconf]
#   --purge-themes  also deletes the MacTahoe themes/icons/fonts from disk
#   --full-dconf    last resort: restores ALL desktop settings exactly as they
#                   were on backup day (overwrites later changes)
# (Spanish aliases: --si --purgar-temas --dconf-completo)
set -Eeuo pipefail
cd "$(dirname "$0")"
SW_ROOT="$(pwd)"

source lib/common.sh
source versions.lock
source lib/ui.sh

PURGE=0
FULL_DCONF=0
while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y|--si) ASSUME_YES=1 ;;
    --purge-themes|--purgar-temas) PURGE=1 ;;
    --full-dconf|--dconf-completo) FULL_DCONF=1 ;;
    -h|--help) grep '^#' "$0" | head -9; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
  shift
done
export ASSUME_YES

[ "$(id -u)" -eq 0 ] && die "${MSG[no_root]}"
[ -f "$SW_MANIFEST" ] || die "${MSG[un_nothing]}"

ui_yesno "${MSG[un_confirm]}" || die "${MSG[cancelled]}"

mkdir -p "$SW_LOGDIR"
LOG="$SW_LOGDIR/uninstall-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1
info "${MSG[log_at]} $LOG"

info "${MSG[un_desktop]}"
python3 lib/restore.py gsettings
python3 lib/restore.py dconf
info "${MSG[un_exts]}"
python3 lib/restore.py extensions
info "${MSG[un_files]}"
python3 lib/restore.py files

# gtk-4.0 (libadwaita): restored from the pristine backup
if python3 lib/manifest.py has-note "libadwaita-installed"; then
  rm -rf "$HOME/.config/gtk-4.0"
  if [ -d "$SW_BACKUP/gtk-4.0" ]; then
    cp -a "$SW_BACKUP/gtk-4.0" "$HOME/.config/gtk-4.0"
  fi
  ok "${MSG[un_libadw_ok]}"
fi

# News heartbeat: disable before its unit files are removed with the manifest
systemctl --user disable --now second-wind-news.timer >/dev/null 2>&1 || true
systemctl --user daemon-reload 2>/dev/null || true

# Ulauncher: stop it if we left it running (its autostart entry is already gone)
pgrep -x ulauncher >/dev/null 2>&1 && pkill -x ulauncher 2>/dev/null || true

# --- sudo part: only if the manifest records system changes ---
NEED_SUDO=0
[ "$(python3 lib/manifest.py get apt_packages)" != "[]" ] && NEED_SUDO=1
[ "$(python3 lib/manifest.py get dkms)" != "[]" ] && NEED_SUDO=1
[ "$(python3 lib/manifest.py get system)" != "[]" ] && NEED_SUDO=1

if [ "$NEED_SUDO" = 1 ]; then
  info "${MSG[un_sys_need]}"
  if sudo -v; then
    # dkms (camera driver)
    while read -r modver; do
      [ -n "$modver" ] || continue
      m="${modver%%/*}"; v="${modver##*/}"
      info "${MSG[un_dkms]} $m…"
      sudo dkms remove -m "$m" -v "$v" --all >/dev/null 2>&1 || true
      sudo rm -rf "/usr/src/$m-$v"
      sudo modprobe -r "$m" 2>/dev/null || true
    done < <(python3 -c "import json,sys; [print(x) for x in json.loads(sys.argv[1])]" "$(python3 lib/manifest.py get dkms)")

    # system files we created/modified
    while read -r path; do
      [ -n "$path" ] || continue
      case "$path" in
        /etc/modprobe.d/secondwind-*|/etc/modprobe.d/macconlinux-*)
          sudo rm -f "$path"
          sudo update-initramfs -u >/dev/null 2>&1 || true
          ok "${MSG[un_file_rm]} $path" ;;
        /etc/gdm3/custom.conf)
          if [ -f "$SW_BACKUP/gdm-custom.conf" ]; then
            sudo cp "$SW_BACKUP/gdm-custom.conf" /etc/gdm3/custom.conf
            ok "${MSG[un_file_rm]} (restored) /etc/gdm3/custom.conf"
          fi ;;
        /usr/lib/firmware/facetimehd*)
          sudo rm -rf /usr/lib/firmware/facetimehd
          ok "${MSG[un_fw_ok]}" ;;
        /etc/systemd/sleep.conf.d/secondwind.conf|/etc/systemd/logind.conf.d/secondwind.conf)
          sudo rm -f "$path"
          sudo systemctl kill -sHUP systemd-logind 2>/dev/null || true
          ok "${MSG[un_file_rm]} $path" ;;
        /etc/default/grub.d/secondwind-hibernate.cfg)
          sudo rm -f "$path"
          sudo update-grub >/dev/null 2>&1 || true
          ok "${MSG[un_file_rm]} $path" ;;
        /etc/initramfs-tools/conf.d/secondwind-resume)
          sudo rm -f "$path"
          sudo update-initramfs -u >/dev/null 2>&1 || true
          ok "${MSG[un_file_rm]} $path" ;;
        /usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource)
          if [ -f "$SW_BACKUP/gnome-shell-theme.gresource.yaru" ]; then
            sudo cp "$SW_BACKUP/gnome-shell-theme.gresource.yaru" "$path"
            sudo rm -f "$path.bak"
            ok "${MSG[un_gdm_ok]}"
          elif [ -f "$path.bak" ]; then
            sudo mv "$path.bak" "$path"
            ok "${MSG[un_gdm_bak_ok]}"
          fi ;;
      esac
    done < <(python3 -c "import json,sys; [print(x['path']) for x in json.loads(sys.argv[1])]" "$(python3 lib/manifest.py get system)")

    # apt packages we installed (mbpfan yes; compilers are kept just in case)
    while read -r p; do
      [ -n "$p" ] || continue
      case "$p" in
        mbpfan)
          sudo systemctl disable --now mbpfan >/dev/null 2>&1 || true
          sudo apt-get remove -y mbpfan >/dev/null 2>&1 && ok "${MSG[un_pkg_rm]} $p" ;;
        *) info "${MSG[un_pkg_keep]} $p)" ;;
      esac
    done < <(python3 -c "import json,sys; [print(x) for x in json.loads(sys.argv[1])]" "$(python3 lib/manifest.py get apt_packages)")
  else
    warn "${MSG[un_no_sudo]}"
  fi
fi

# Swap file: shrink back to its original size if we enlarged it for hibernation
if python3 lib/manifest.py has-note "swap-resized" 2>/dev/null \
   && [ -f "$SW_BACKUP/swap-original-bytes" ]; then
  ORIG="$(cat "$SW_BACKUP/swap-original-bytes")"
  if [ "$ORIG" -gt 0 ] && { sudo -n true 2>/dev/null || sudo -v; }; then
    sudo swapoff /swap.img 2>/dev/null || true
    sudo fallocate -l "$ORIG" /swap.img
    sudo chmod 600 /swap.img
    sudo mkswap /swap.img >/dev/null
    sudo swapon /swap.img 2>/dev/null || true
    ok "${MSG[un_file_rm]} (swap restored to original size)"
  fi
fi

# Chrome: restore its window preference (only if we touched it and it is closed)
if python3 lib/manifest.py has-note "chrome-patched" 2>/dev/null; then
  if pgrep -x chrome >/dev/null 2>&1; then
    warn "${MSG[un_chrome_open]}"
  elif [ -f "$SW_STATE/chrome-prefs-before.json" ] || [ -f "$SW_STATE/chrome-prefs-antes.json" ]; then
    python3 - "$HOME/.config/google-chrome/Default/Preferences" "$SW_STATE" <<'PY'
import json, os, sys
prefs_p, state = sys.argv[1], sys.argv[2]
before_p = os.path.join(state, "chrome-prefs-before.json")
if not os.path.exists(before_p):
    before_p = os.path.join(state, "chrome-prefs-antes.json")
try:
    with open(prefs_p) as f:
        d = json.load(f)
    with open(before_p) as f:
        before = json.load(f).get("custom_chrome_frame", "__absent__")
    if before in ("__absent__", "__ausente__"):
        d.get("browser", {}).pop("custom_chrome_frame", None)
    else:
        d.setdefault("browser", {})["custom_chrome_frame"] = before
    tmp = prefs_p + ".secondwind.tmp"
    with open(tmp, "w") as f:
        json.dump(d, f)
    os.replace(tmp, prefs_p)
    print("  Chrome: window preference restored")
except FileNotFoundError:
    pass
PY
  fi
fi

# --- extra options ---
if [ "$PURGE" = 1 ]; then
  info "${MSG[un_purge]}"
  if [ -d "$SW_CACHE/MacTahoe-gtk-theme" ]; then
    ( cd "$SW_CACHE/MacTahoe-gtk-theme" && ./install.sh -r theme >/dev/null 2>&1 ) || true
  fi
  rm -rf "$HOME"/.themes/MacTahoe-* "$HOME"/.themes/SecondWind-* "$HOME"/.themes/MacConLinux-* 2>/dev/null || true
  rm -rf "$HOME"/.local/share/icons/MacTahoe* 2>/dev/null || true
  ok "${MSG[un_purge_ok]}"
fi

if [ "$FULL_DCONF" = 1 ]; then
  if [ -f "$SW_BACKUP/dconf-full.ini" ]; then
    warn "${MSG[un_dconf_warn]}"
    dconf load / < "$SW_BACKUP/dconf-full.ini"
    ok "${MSG[un_dconf_ok]}"
  else
    warn "${MSG[un_dconf_missing]}"
  fi
fi

# The manifest has been applied: archive it (kept for traceability)
mv "$SW_MANIFEST" "$SW_MANIFEST.restored-$(date +%Y%m%d-%H%M%S)"

echo
ok "${MSG[un_done]}"
