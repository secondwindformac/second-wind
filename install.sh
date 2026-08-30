#!/usr/bin/env bash
# MacConLinux — instalador one-click de la experiencia macOS para Ubuntu
# Uso:  ./install.sh [--dry-run] [--si] [--sin-hardware] [--solo MODULO]...
#       ./install.sh --verificar | --desinstalar | --help
set -Eeuo pipefail
cd "$(dirname "$0")"
MCL_ROOT="$(pwd)"

source lib/common.sh
source versions.lock
source lib/i18n/es.sh
source lib/ui.sh

uso() {
  cat <<'EOF'
MacConLinux — experiencia macOS para Ubuntu (24.04, GNOME 46)

  ./install.sh              instalación normal (interactiva)
  ./install.sh --si         sin preguntas: acepta los valores por defecto
  ./install.sh --dry-run    muestra qué haría, sin cambiar nada
  ./install.sh --sin-hardware   omite el módulo que pide contraseña de administrador
  ./install.sh --solo M     ejecuta solo un módulo (ej: --solo hardware, --solo dock)
  ./install.sh --verificar  comprueba el estado de la instalación
  ./install.sh --desinstalar    restaura Ubuntu como estaba
EOF
}

MODULOS_SOLO=()
CON_HARDWARE=1
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --si|--yes|-y) ASSUME_YES=1 ;;
    --sin-hardware) CON_HARDWARE=0 ;;
    --solo) shift; [ $# -gt 0 ] || die "--solo requiere un nombre de módulo"; MODULOS_SOLO+=("$1") ;;
    --verificar) exec ./verify.sh --todo ;;
    --desinstalar) exec ./uninstall.sh ;;
    -h|--help) uso; exit 0 ;;
    *) die "Opción desconocida: $1 (mira ./install.sh --help)" ;;
  esac
  shift
done
export DRY_RUN ASSUME_YES

[ "$(id -u)" -eq 0 ] && die "${MSG[no_root]}"

# ---- fase de preguntas (antes de redirigir la salida, para no romper whiptail) ----
if [ ${#MODULOS_SOLO[@]} -eq 0 ]; then
  ui_msg "${MSG[bienvenida]}"
  ui_yesno "${MSG[confirmar]}" || die "${MSG[cancelado]}"
  if [ "$CON_HARDWARE" = 1 ] && [ "$ASSUME_YES" != 1 ] && ui_has_tty; then
    ui_yesno "${MSG[preg_hardware]}" || CON_HARDWARE=0
  fi
fi

# ---- fase de trabajo: todo queda en el registro ----
mkdir -p "$MCL_LOGDIR"
LOG="$MCL_LOGDIR/install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1
info "Registro completo: $LOG"
[ "$DRY_RUN" = 1 ] && warn "${MSG[modo_prueba]}"

# Módulos críticos: en el shell principal (sus variables persisten; si fallan, se aborta).
source modules/00-preflight.sh
source modules/10-backup.sh

MODULES=(20-apariencia 30-extensiones 35-dock 40-panel 45-teclado 50-spotlight 55-navegadores)
[ "$CON_HARDWARE" = 1 ] && MODULES+=(60-hardware 65-gdm)
MODULES+=(70-apps 90-postlogin)

if [ ${#MODULOS_SOLO[@]} -gt 0 ]; then
  TODOS=(20-apariencia 30-extensiones 35-dock 40-panel 45-teclado 50-spotlight 55-navegadores 60-hardware 65-gdm 70-apps 90-postlogin)
  MODULES=()
  for m in "${TODOS[@]}"; do
    for pedido in "${MODULOS_SOLO[@]}"; do
      case "$m" in *"$pedido"*) MODULES+=("$m") ;; esac
    done
  done
  [ ${#MODULES[@]} -gt 0 ] || die "Ningún módulo coincide con: ${MODULOS_SOLO[*]}"
fi

total=${#MODULES[@]}
i=0
OMITIDOS=()
for m in "${MODULES[@]}"; do
  i=$((i + 1))
  clave="mod_${m%%-*}"
  ui_step "$i" "$total" "${MSG[$clave]:-$m}"
  if ( set -Eeuo pipefail; source "modules/$m.sh" ); then
    ok "${MSG[$clave]:-$m}: listo"
  else
    warn "${MSG[$clave]:-$m}: omitido (detalle arriba; el resto continúa)"
    OMITIDOS+=("$m")
  fi
done

echo
if [ ${#OMITIDOS[@]} -eq 0 ]; then
  ok "${MSG[fin_ok]}"
else
  warn "${MSG[fin_avisos]}"
fi

if [ "$DRY_RUN" != 1 ] && [ ${#MODULOS_SOLO[@]} -eq 0 ]; then
  echo
  if ui_yesno "${MSG[preg_logout]}" --default-no; then
    gnome-session-quit --logout --no-prompt
  else
    info "${MSG[logout_manual]}"
  fi
fi
