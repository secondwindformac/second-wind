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

# --- one-time graphical privilege escalation (askpass, NOT pkexec) ---
# pkexec elevates a separate process and does NOT populate sudo's credential
# cache; the modules use sudo, so we authenticate sudo itself once via a zenity
# SUDO_ASKPASS helper and keep the timestamp warm for the whole run.
SW_GUI_ASKPASS=""; SW_GUI_KEEPALIVE=""
gui_auth_begin() {
  SW_GUI_ASKPASS="$(mktemp)"; chmod 0700 "$SW_GUI_ASKPASS"
  # Helper prints the password to STDOUT ONLY; it never stores or logs it.
  cat > "$SW_GUI_ASKPASS" <<EOF
#!/bin/sh
exec zenity --password --title="Second Wind" 2>/dev/null
EOF
  chmod 0700 "$SW_GUI_ASKPASS"
  export SUDO_ASKPASS="$SW_GUI_ASKPASS"
  sudo -A -v || { gui_auth_end; return 1; }        # ask once (graphical)
  ( while sleep 50; do sudo -n true 2>/dev/null || exit; done ) &
  SW_GUI_KEEPALIVE=$!
  return 0
}
# gui_auth_ensure -> 0 if privileged calls will work; else fail LOUD (caller
# shows gui_error). Never returns silently-broken.
gui_auth_ensure() {
  sudo -n true 2>/dev/null && return 0
  sudo -A -v 2>/dev/null && return 0               # one graphical re-ask
  return 1
}
gui_auth_end() {
  [ -n "$SW_GUI_KEEPALIVE" ] && kill "$SW_GUI_KEEPALIVE" 2>/dev/null || true
  [ -n "$SW_GUI_ASKPASS" ] && rm -f "$SW_GUI_ASKPASS" || true
  SW_GUI_KEEPALIVE=""; SW_GUI_ASKPASS=""; unset SUDO_ASKPASS 2>/dev/null || true
}

# --- phase-based progress window (pulsating; deterministic close) ---
SW_PROGRESS_FIFO=""; SW_PROGRESS_PID=""; SW_PROGRESS_WFD=""
gui_progress_open() {
  local dir; dir="$(mktemp -d)"; SW_PROGRESS_FIFO="$dir/p"
  mkfifo "$SW_PROGRESS_FIFO"
  ( zenity --progress --pulsate --no-cancel --auto-close \
      --title="Second Wind" --text="${1:-…}" < "$SW_PROGRESS_FIFO" 2>/dev/null ) &
  SW_PROGRESS_PID=$!
  exec {SW_PROGRESS_WFD}>"$SW_PROGRESS_FIFO"   # hold the write end open across updates
  export SW_PROGRESS_FIFO
}
gui_progress_update() {
  [ -n "$SW_PROGRESS_FIFO" ] && [ -p "$SW_PROGRESS_FIFO" ] || return 0
  printf '# %s\n' "$1" >&"$SW_PROGRESS_WFD" 2>/dev/null || true
}
gui_progress_close() {
  [ -n "$SW_PROGRESS_WFD" ] && { exec {SW_PROGRESS_WFD}>&- 2>/dev/null || true; SW_PROGRESS_WFD=""; }
  [ -n "$SW_PROGRESS_PID" ] && wait "$SW_PROGRESS_PID" 2>/dev/null || true
  [ -n "$SW_PROGRESS_FIFO" ] && rm -rf "$(dirname "$SW_PROGRESS_FIFO")" 2>/dev/null || true
  SW_PROGRESS_FIFO=""; SW_PROGRESS_PID=""
}
