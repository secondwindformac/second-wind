#!/usr/bin/env bash
# Second Wind — graphical shell around install.sh for the GUIDED first boot.
# Only active when SW_UI=gui; every helper degrades to a no-op / false so the
# terminal path (standalone ./install.sh) is never affected. Uses zenity (GTK).

SW_UI="${SW_UI:-terminal}"

# gui_available -> 0 when a graphical dialog can actually be shown.
gui_available() {
  command -v zenity >/dev/null 2>&1 && { [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; }
}

# gui_consent BODY -> 0 (yes) / 1 (no). One informative confirmation.
gui_consent() {
  zenity --question --no-wrap --title="Second Wind" \
    --ok-label="${MSG[gui_ok]:-Continue}" --cancel-label="${MSG[gui_cancel]:-Not now}" \
    --text="$1" 2>/dev/null
}

# gui_error BODY LOGPATH — a clear, dismissable error (never a mute hang).
gui_error() {
  zenity --error --no-wrap --title="${MSG[gui_err_title]:-Second Wind}" \
    --text="$1"$'\n\n'"${MSG[gui_err_log]:-Log:} $2" 2>/dev/null || true
}
