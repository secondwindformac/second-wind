#!/usr/bin/env bash
# UI del instalador: whiptail cuando hay terminal interactiva, texto plano si no.
# Con --si (ASSUME_YES=1) no se pregunta nada: se usan los valores por defecto.

UI_TITLE="MacConLinux"

ui_has_tty() { [ -t 0 ] && [ -t 1 ]; }

ui_use_whiptail() {
  ui_has_tty && [ "$ASSUME_YES" != 1 ] && command -v whiptail >/dev/null 2>&1
}

# ui_msg TEXTO — pantalla informativa.
ui_msg() {
  if ui_use_whiptail; then
    whiptail --backtitle "$UI_TITLE" --title "$UI_TITLE" --msgbox "$1" 22 76
  else
    printf '\n%s\n\n' "$1"
  fi
}

# ui_yesno PREGUNTA [--default-no] → 0 sí / 1 no.
# Sin terminal o con --si: responde el valor por defecto (sí, salvo --default-no).
ui_yesno() {
  local q="$1" defno="${2:-}"
  if [ "$ASSUME_YES" = 1 ] || ! ui_has_tty; then
    [ "$defno" = "--default-no" ] && return 1 || return 0
  fi
  if command -v whiptail >/dev/null 2>&1; then
    local extra=()
    [ "$defno" = "--default-no" ] && extra=(--defaultno)
    whiptail --backtitle "$UI_TITLE" --title "$UI_TITLE" "${extra[@]}" --yesno "$q" 14 76
  else
    local ans
    read -r -p "$q [s/n] " ans
    [[ "$ans" =~ ^[sS] ]]
  fi
}

ui_step() { printf '\n%s[%s/%s] %s%s\n' "$C_INFO" "$1" "$2" "$3" "$C_OFF"; }
