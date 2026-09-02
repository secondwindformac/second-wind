#!/usr/bin/env bash
# Second Wind — one-click macOS experience installer for Ubuntu.
# A second wind for your old Mac.
#
# Usage:  ./install.sh [--dry-run] [--yes] [--no-hardware] [--only MODULE]...
#         ./install.sh --verify | --uninstall | --help
# (Spanish aliases kept for compatibility: --si --sin-hardware --solo
#  --verificar --desinstalar)
set -Eeuo pipefail
cd "$(dirname "$0")"
SW_ROOT="$(pwd)"

source lib/common.sh
source versions.lock
source lib/ui.sh

usage() {
  cat <<'EOF'
Second Wind — macOS experience for Ubuntu (24.04, GNOME 46)

  ./install.sh                normal (interactive) install
  ./install.sh --yes          no questions: accept the defaults
  ./install.sh --dry-run      show what would be done, change nothing
  ./install.sh --no-hardware  skip the steps that ask for the admin password
  ./install.sh --only M       run a single module (e.g. --only hardware, --only dock)
  ./install.sh --verify       check the state of the installation
  ./install.sh --uninstall    restore Ubuntu as it was
EOF
}

# Spanish module aliases (kept so older docs/commands keep working)
map_alias() {
  case "$1" in
    motores) echo engines ;;
    apariencia) echo look ;;
    extensiones) echo extensions ;;
    teclado) echo keyboard ;;
    navegadores) echo browsers ;;
    *) echo "$1" ;;
  esac
}

ONLY_MODULES=()
WITH_HARDWARE=1
FIRSTBOOT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --yes|-y|--si) ASSUME_YES=1 ;;
    --no-hardware|--sin-hardware) WITH_HARDWARE=0 ;;
    # Internal: the USB firstboot sets this. It tells us NOT to run our own
    # end-of-install logout prompt — firstboot reboots the machine itself once
    # we finish (a fresh GNOME shell is what actually loads the extensions).
    --firstboot) FIRSTBOOT=1 ;;
    --only|--solo) shift; [ $# -gt 0 ] || die "--only requires a module name"; ONLY_MODULES+=("$1") ;;
    --verify|--verificar) exec ./verify.sh --all ;;
    --uninstall|--desinstalar) exec ./uninstall.sh ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1 (see ./install.sh --help)" ;;
  esac
  shift
done
export DRY_RUN ASSUME_YES

[ "$(id -u)" -eq 0 ] && die "${MSG[no_root]}"

# ---- question phase (before redirecting output, so whiptail renders fine) ----
if [ ${#ONLY_MODULES[@]} -eq 0 ]; then
  ui_msg "${MSG[welcome]}"
  ui_yesno "${MSG[confirm]}" || die "${MSG[cancelled]}"
  if [ "$WITH_HARDWARE" = 1 ] && [ "$ASSUME_YES" != 1 ] && ui_has_tty; then
    ui_yesno "${MSG[ask_hardware]}" || WITH_HARDWARE=0
  fi
fi

# ---- work phase: everything goes to the log ----
mkdir -p "$SW_LOGDIR"
LOG="$SW_LOGDIR/install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1
info "${MSG[log_at]} $LOG"
[ "$DRY_RUN" = 1 ] && warn "${MSG[dry_run_notice]}"

# Critical modules run in the main shell (their variables persist; a failure aborts).
source modules/00-preflight.sh
source modules/10-backup.sh

MODULES=()
[ "$WITH_HARDWARE" = 1 ] && MODULES+=(15-engines)
MODULES+=(20-look 30-extensions 35-dock 40-panel 45-keyboard 50-spotlight 55-browsers)
[ "$WITH_HARDWARE" = 1 ] && MODULES+=(60-hardware 62-power 65-gdm)
MODULES+=(70-apps 75-news 76-experience 80-updater 85-quiet 90-postlogin)

if [ ${#ONLY_MODULES[@]} -gt 0 ]; then
  ALL=(15-engines 20-look 30-extensions 35-dock 40-panel 45-keyboard 50-spotlight 55-browsers 60-hardware 62-power 65-gdm 70-apps 75-news 76-experience 80-updater 85-quiet 90-postlogin)
  MODULES=()
  for m in "${ALL[@]}"; do
    for wanted in "${ONLY_MODULES[@]}"; do
      case "$m" in *"$(map_alias "$wanted")"*) MODULES+=("$m") ;; esac
    done
  done
  [ ${#MODULES[@]} -gt 0 ] || die "No module matches: ${ONLY_MODULES[*]}"
fi

total=${#MODULES[@]}
i=0
SKIPPED=()
for m in "${MODULES[@]}"; do
  i=$((i + 1))
  key="mod_${m%%-*}"
  ui_step "$i" "$total" "${MSG[$key]:-$m}"
  if ( set -Eeuo pipefail; source "modules/$m.sh" ); then
    ok "${MSG[$key]:-$m}: ${MSG[mod_done]}"
  else
    warn "${MSG[$key]:-$m}: ${MSG[mod_skipped]}"
    SKIPPED+=("$m")
  fi
done

echo
if [ ${#SKIPPED[@]} -eq 0 ]; then
  ok "${MSG[final_ok]}"
else
  warn "${MSG[final_warn]}"
fi
[ ${#ONLY_MODULES[@]} -eq 0 ] && info "${MSG[trial_note]}"

# A standalone run asks (default no) whether to end the session — reboots are
# manual by design when someone runs this on a machine they are already using.
# The guided USB firstboot (--firstboot) is different: it is a brand-new machine
# and firstboot restarts it for us, so we skip the prompt here.
if [ "$DRY_RUN" != 1 ] && [ ${#ONLY_MODULES[@]} -eq 0 ] && [ "$FIRSTBOOT" != 1 ]; then
  echo
  if ui_yesno "${MSG[ask_logout]}" --default-no; then
    gnome-session-quit --logout --no-prompt
  else
    info "${MSG[logout_manual]}"
  fi
fi
