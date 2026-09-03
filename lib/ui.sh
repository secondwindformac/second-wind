#!/usr/bin/env bash
# Second Wind installer UI: whiptail when there is an interactive terminal,
# plain text otherwise. With --yes (ASSUME_YES=1) nothing is asked: defaults apply.

UI_TITLE="Second Wind"

ui_has_tty() { [ -t 0 ] && [ -t 1 ]; }

ui_use_whiptail() {
  ui_has_tty && [ "$ASSUME_YES" != 1 ] && command -v whiptail >/dev/null 2>&1
}

# ui_msg TEXT — informational screen.
ui_msg() {
  if ui_use_whiptail; then
    whiptail --backtitle "$UI_TITLE" --title "$UI_TITLE" --msgbox "$1" 22 76
  else
    printf '\n%s\n\n' "$1"
  fi
}

# ui_yesno QUESTION [--default-no] → 0 yes / 1 no.
# Without a terminal or with --yes: returns the default (yes, unless --default-no).
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
    read -r -p "$q [y/n] " ans
    [[ "$ans" =~ ^[yYsS] ]]
  fi
}

# ui_step CURRENT TOTAL LABEL — a step marker. In the guided GUI first boot
# (SW_UI=gui) it drives the graphical progress window instead of printing.
ui_step() {
  if [ "${SW_UI:-terminal}" = gui ]; then
    gui_progress_update "$3"
  else
    printf '\n%s[%s/%s] %s%s\n' "$C_INFO" "$1" "$2" "$3" "$C_OFF"
  fi
}

# ui_error TEXT [LOGPATH] — a visible error. GUI: a dialog; terminal: stderr.
ui_error() {
  if [ "${SW_UI:-terminal}" = gui ]; then
    gui_error "$1" "${2:-}"
  else
    printf '%s\n' "$1" >&2
  fi
}
