#!/usr/bin/env bash
# MacConLinux — desinstalador. Restaura la configuración original de Ubuntu
# usando el manifiesto de cambios y el respaldo prístino.
# Uso: ./uninstall.sh [--si] [--purgar-temas] [--dconf-completo]
#   --purgar-temas    además borra los temas/iconos/fuentes MacTahoe del disco
#   --dconf-completo  último recurso: repone TODA la configuración de escritorio
#                     tal como estaba el día del respaldo (pisa cambios posteriores)
set -Eeuo pipefail
cd "$(dirname "$0")"
MCL_ROOT="$(pwd)"

source lib/common.sh
source versions.lock
source lib/i18n/es.sh
source lib/ui.sh

PURGAR=0
DCONF_COMPLETO=0
while [ $# -gt 0 ]; do
  case "$1" in
    --si|--yes|-y) ASSUME_YES=1 ;;
    --purgar-temas) PURGAR=1 ;;
    --dconf-completo) DCONF_COMPLETO=1 ;;
    -h|--help) grep '^#' "$0" | head -8; exit 0 ;;
    *) die "Opción desconocida: $1" ;;
  esac
  shift
done
export ASSUME_YES

[ "$(id -u)" -eq 0 ] && die "${MSG[no_root]}"
[ -f "$MCL_MANIFEST" ] || die "No hay manifiesto de cambios ($MCL_MANIFEST); no hay nada que restaurar."

ui_yesno "${MSG[des_confirmar]}" || die "${MSG[cancelado]}"

mkdir -p "$MCL_LOGDIR"
LOG="$MCL_LOGDIR/uninstall-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1
info "Registro: $LOG"

info "Restaurando configuración del escritorio…"
python3 lib/restore.py gsettings
python3 lib/restore.py dconf
info "Quitando extensiones instaladas por MacConLinux…"
python3 lib/restore.py extensiones
info "Quitando archivos creados por MacConLinux…"
python3 lib/restore.py archivos

# gtk-4.0 (libadwaita): se repone desde el respaldo prístino
if python3 lib/manifest.py has-note "libadwaita-instalado"; then
  rm -rf "$HOME/.config/gtk-4.0"
  if [ -d "$MCL_BACKUP/gtk-4.0" ]; then
    cp -a "$MCL_BACKUP/gtk-4.0" "$HOME/.config/gtk-4.0"
  fi
  ok "Tema de aplicaciones modernas (gtk-4.0) restaurado"
fi

# Ulauncher: cerrar si lo dejamos corriendo (su autostart ya fue eliminado)
pgrep -x ulauncher >/dev/null 2>&1 && pkill -x ulauncher 2>/dev/null || true

# --- parte con sudo: solo si el manifiesto registra cambios de sistema ---
NECESITA_SUDO=0
[ "$(python3 lib/manifest.py get paquetes_apt)" != "[]" ] && NECESITA_SUDO=1
[ "$(python3 lib/manifest.py get dkms)" != "[]" ] && NECESITA_SUDO=1
[ "$(python3 lib/manifest.py get sistema)" != "[]" ] && NECESITA_SUDO=1

if [ "$NECESITA_SUDO" = 1 ]; then
  info "Hay cambios de hardware/sistema que revertir; se necesita tu contraseña de administrador."
  if sudo -v; then
    # dkms (driver de cámara)
    while read -r modver; do
      [ -n "$modver" ] || continue
      m="${modver%%/*}"; v="${modver##*/}"
      info "Quitando driver $m…"
      sudo dkms remove -m "$m" -v "$v" --all >/dev/null 2>&1 || true
      sudo rm -rf "/usr/src/$m-$v"
      sudo modprobe -r "$m" 2>/dev/null || true
    done < <(python3 -c "import json,sys; [print(x) for x in json.loads(sys.argv[1])]" "$(python3 lib/manifest.py get dkms)")

    # archivos de sistema que creamos/modificamos
    while read -r ruta; do
      [ -n "$ruta" ] || continue
      case "$ruta" in
        /etc/modprobe.d/macconlinux-*)
          sudo rm -f "$ruta"
          sudo update-initramfs -u >/dev/null 2>&1 || true
          ok "Eliminado $ruta" ;;
        /etc/gdm3/custom.conf)
          if [ -f "$MCL_BACKUP/gdm-custom.conf" ]; then
            sudo cp "$MCL_BACKUP/gdm-custom.conf" /etc/gdm3/custom.conf
            ok "Restaurado /etc/gdm3/custom.conf (inicio de sesión como antes)"
          fi ;;
        /usr/lib/firmware/facetimehd*)
          sudo rm -rf /usr/lib/firmware/facetimehd
          ok "Firmware de cámara eliminado" ;;
      esac
    done < <(python3 -c "import json,sys; [print(x['ruta']) for x in json.loads(sys.argv[1])]" "$(python3 lib/manifest.py get sistema)")

    # paquetes apt que instalamos (mbpfan sí; compiladores se conservan por si acaso)
    while read -r p; do
      [ -n "$p" ] || continue
      case "$p" in
        mbpfan)
          sudo systemctl disable --now mbpfan >/dev/null 2>&1 || true
          sudo apt-get remove -y mbpfan >/dev/null 2>&1 && ok "Paquete $p eliminado" ;;
        *) info "Se conserva el paquete $p (herramienta genérica; puedes quitarlo con: sudo apt remove $p)" ;;
      esac
    done < <(python3 -c "import json,sys; [print(x) for x in json.loads(sys.argv[1])]" "$(python3 lib/manifest.py get paquetes_apt)")
  else
    warn "Sin permisos de administrador: los cambios de hardware quedaron sin revertir (repite luego ./uninstall.sh)."
  fi
fi

# --- opciones extra ---
if [ "$PURGAR" = 1 ]; then
  info "Purgando temas MacTahoe del disco…"
  if [ -d "$MCL_CACHE/MacTahoe-gtk-theme" ]; then
    ( cd "$MCL_CACHE/MacTahoe-gtk-theme" && ./install.sh -r theme >/dev/null 2>&1 ) || true
  fi
  rm -rf "$HOME"/.themes/MacTahoe-* 2>/dev/null || true
  rm -rf "$HOME"/.local/share/icons/MacTahoe* 2>/dev/null || true
  ok "Temas purgados"
fi

if [ "$DCONF_COMPLETO" = 1 ]; then
  if [ -f "$MCL_BACKUP/dconf-full.ini" ]; then
    warn "Reponiendo TODA la configuración de escritorio del día del respaldo…"
    dconf load / < "$MCL_BACKUP/dconf-full.ini"
    ok "Configuración completa restaurada"
  else
    warn "No existe el respaldo dconf completo"
  fi
fi

# El manifiesto ya se aplicó: se archiva (no se borra, por trazabilidad)
mv "$MCL_MANIFEST" "$MCL_MANIFEST.restaurado-$(date +%Y%m%d-%H%M%S)"

echo
ok "${MSG[des_fin]}"
