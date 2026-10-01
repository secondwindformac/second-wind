#!/bin/bash
# Second Wind — first-login bootstrap, installed by the USB autoinstaller.
# Waits for internet, then opens the regular Second Wind installer in a
# terminal (one confirmation + the user's password for the admin steps).
#
# Council blocker "firstboot with retry": the autostart stays ARMED until the
# installer finishes successfully. A power cut, a closed lid or a failed run
# simply means the next login picks up where things stopped (the installer
# is idempotent by design). Only success disarms it.

SWDIR=/usr/local/share/second-wind
SW_STATE="$HOME/.local/state/second-wind"
LOGDIR="$SW_STATE/logs"
STAMP="$SW_STATE/firstboot-done"
AUTOSTART="$HOME/.config/autostart/second-wind-firstboot.desktop"
mkdir -p "$LOGDIR"
exec >>"$LOGDIR/firstboot.log" 2>&1
echo "=== firstboot $(date -Is) ==="

# Success on a previous login? Just clean up and stay quiet forever.
if [ -f "$STAMP" ]; then
  rm -f "$AUTOSTART"
  exit 0
fi

[ -x "$SWDIR/install.sh" ] || { echo "second-wind payload missing"; exit 0; }

# --- which phase runs? (docs/modo-fabrica.md 3.3) --------------------------
# The system markers are the source of truth: the technician's home (and its
# stamp) is deleted at delivery, so the home stamp cannot remember the phase.
# >>> factory-phase (tests/factory/test_firstboot_phase.sh reads this block)
SW_ETC="${SW_ETC:-/etc/second-wind}"
if [ -f "$SW_ETC/factory" ] && [ ! -f "$SW_ETC/system-done" ]; then
  PHASE=factory            # factory phase: system modules only
  INSTALL_ARGS="--firstboot --factory"
elif [ -f "$SW_ETC/factory" ]; then
  PHASE=skip               # factory already done, delivery pending
elif [ -f "$SW_ETC/system-done" ]; then
  PHASE=user               # buyer phase: user modules only
  INSTALL_ARGS="--firstboot --user-only"
else
  PHASE=normal             # no markers: the original one-shot conversion
  INSTALL_ARGS="--firstboot"
fi
# <<< factory-phase
echo "phase: $PHASE"
if [ "$PHASE" = skip ]; then
  rm -f "$AUTOSTART"
  exit 0
fi

# R9 polish: Ubuntu's first-login windows (the "Complete your setup" wizard and
# "Software Updater") launch WITH the session — before module 85-quiet, which
# runs near the end of the install, can write its overrides. Close them here
# (and once more right before the conversion starts) so the person's very
# first screen stays clean; 85-quiet then prevents every FUTURE login.
# Killing is safe: the wizard is optional and update-notifier only pops a
# window — apt, updates and security are untouched.
quiet_first_login() {
  pkill -f gnome-initial-setup 2>/dev/null || true
  pkill -f update-notifier 2>/dev/null || true
}
quiet_first_login

# Load the payload helpers so we can show the friendly graphical conversion
# (gui_* dialogs + translated MSG strings). Safe if it is missing — we then use
# the terminal path below.
export SW_ROOT="$SWDIR"
# shellcheck disable=SC1091
[ -f "$SWDIR/lib/common.sh" ] && source "$SWDIR/lib/common.sh"

ATTEMPT_FILE="$SW_STATE/firstboot-attempt"
ATTEMPT=$(( $(cat "$ATTEMPT_FILE" 2>/dev/null || echo 0) + 1 ))
echo "$ATTEMPT" > "$ATTEMPT_FILE"

case "${LANG:-en}" in
  es*)
    T_NET="Conéctate a tu WiFi para terminar de convertir tu Mac (ícono arriba a la derecha)."
    T_NET_NOWIFI="Tu WiFi todavía no tiene su driver. Conéctate a internet por cable, o comparte internet del teléfono por cable USB, para terminar de convertir tu Mac."
    T_GO="Segundos… abriendo el instalador de Second Wind. No apagues el Mac durante estos minutos."
    T_RETRY="Retomando la preparación de tu Mac donde quedó — no se perdió nada."
    T_AGAIN="La preparación quedó a medias. Al próximo inicio de sesión se retoma sola; no se perdió nada."
    T_DONE="¡Casi listo! Reiniciamos tu Mac para aplicar los últimos toques. Vuelve a iniciar sesión y ya estará."
    ;;
  *)
    T_NET="Connect to your WiFi to finish turning this into a Mac (icon at the top right)."
    T_NET_NOWIFI="Your WiFi doesn't have its driver yet. Connect to the internet by cable, or share your phone's internet over USB, to finish turning this into a Mac."
    T_GO="Seconds… opening the Second Wind installer. Don't turn the Mac off during these minutes."
    T_RETRY="Picking up your Mac's preparation where it stopped — nothing was lost."
    T_AGAIN="The preparation stopped halfway. It resumes by itself at your next login; nothing was lost."
    T_DONE="Almost there! Restarting your Mac to apply the final touches. Log back in and it's ready."
    ;;
esac

# Normally the WiFi already works here (Broadcom Macs get their driver offline
# during the install). Only if a wl-type Broadcom chip has NO driver loaded do
# we point to the wired / phone-sharing fallback.
if [ -f "$SWDIR/usb/drivers/wl-pci-ids" ] && ! grep -qE '^(wl|brcmfmac|b43|brcmsmac) ' /proc/modules; then
  for dev in /sys/bus/pci/devices/*; do
    id="$(sed 's/^0x//' "$dev/vendor" 2>/dev/null):$(sed 's/^0x//' "$dev/device" 2>/dev/null)"
    if grep -qix "$id" "$SWDIR/usb/drivers/wl-pci-ids"; then T_NET="$T_NET_NOWIFI"; break; fi
  done
fi

# Give the desktop a moment to settle
sleep 15

if [ "$ATTEMPT" -gt 1 ]; then
  notify-send -a "Second Wind" -i view-refresh-symbolic "Second Wind" "$T_RETRY" 2>/dev/null || true
fi

# Wait for connectivity, reminding gently. Never depend on curl alone:
# a stock Ubuntu Desktop install ships without it (VM-rehearsal lesson).
net_ok() {
  nm-online -q -t 15 2>/dev/null && return 0
  ping -c1 -W3 archive.ubuntu.com >/dev/null 2>&1 && return 0
  command -v curl >/dev/null 2>&1 && curl -fsI -m 5 https://extensions.gnome.org >/dev/null 2>&1
}
until net_ok; do
  notify-send -a "Second Wind" -i network-wireless "Second Wind" "$T_NET" 2>/dev/null || true
  sleep 40
done
# Second sweep: anything Ubuntu popped while we waited for the network dies
# now, right before the conversion window takes the screen. And KEEP them dead
# DURING the conversion: update-notifier re-launches on apt activity (R10
# caught it popping mid-install), so a watchdog sweeps every few seconds until
# this script exits (the success path reboots right after). User-level only.
quiet_first_login
( while :; do quiet_first_login; sleep 8; done ) &
QUIET_LOOP=$!
trap 'kill "$QUIET_LOOP" 2>/dev/null || true' EXIT
# Shared success tail: announce, then reboot ONCE so a FRESH gnome-shell loads
# the Mac look (extensions only take effect on a new shell; this also boots the
# GA kernel). Called only after a successful install (STAMP set, autostart gone),
# so it fires exactly once and never loops.
reboot_to_finish() {
  # After this reboot, show "Your Mac" ONCE: the model (with its Apple model
  # number, e.g. A1466) and a real check of WiFi, sound, camera, trackpad...
  # The entry removes itself after showing.
  mkdir -p "$HOME/.config/autostart"
  cat > "$HOME/.config/autostart/second-wind-mymac.desktop" <<EOD
[Desktop Entry]
Type=Application
Name=Second Wind
NoDisplay=true
Exec=sh -c 'sleep 20; "$SWDIR/bin/second-wind-mymac" --gui; rm -f "\$HOME/.config/autostart/second-wind-mymac.desktop"'
X-GNOME-Autostart-enabled=true
EOD
  notify-send -a "Second Wind" -i emblem-ok-symbolic "Second Wind" "$T_DONE" 2>/dev/null || true
  sleep 6
  gnome-session-quit --reboot --no-prompt 2>/dev/null \
    || systemctl reboot 2>/dev/null \
    || sudo -n systemctl reboot 2>/dev/null \
    || true
}

# What to do when a phase succeeds. The factory phase announces nothing to the
# technician (delivery wipes this user and powers off); the buyer's phases get
# the success stamp and the final reboot so a fresh shell loads the Mac look.
after_success() {
  if [ "$PHASE" = factory ]; then
    rm -f "$AUTOSTART"
    return 0
  fi
  touch "$STAMP"; rm -f "$AUTOSTART"
  reboot_to_finish
}

# Preferred path: the friendly GRAPHICAL conversion — ONE consent, ONE graphical
# password, a progress window — with install.sh running hidden. Only taken when a
# real dialog can be shown; otherwise we fall through to the terminal path below
# (never to an invisible whiptail in a session with no terminal).
if command -v gui_available >/dev/null 2>&1 && gui_available; then
  if gui_consent "${MSG[gui_consent]}" && gui_auth_begin; then
    # Safety net: whatever happens, remove the temporary passwordless rule and
    # close the progress window (the normal paths below also do this).
    trap 'kill "$QUIET_LOOP" 2>/dev/null || true; gui_auth_end 2>/dev/null || true; gui_progress_close 2>/dev/null || true' EXIT
    gui_progress_open "${MSG[gui_phase_prep]}"
    # shellcheck disable=SC2086
    SW_UI=gui "$SWDIR/install.sh" $INSTALL_ARGS
    rc=$?
    gui_progress_close
    gui_auth_end
    if [ "$rc" = 0 ]; then
      after_success
    else
      # A visible, dismissable error. The autostart stays armed, so the next
      # login retries where it stopped (install.sh is idempotent).
      gui_error "${MSG[gui_err_body]}" "$LOGDIR"
    fi
  else
    # "Not now" or a cancelled password: stay armed and quiet; retry next login.
    gui_auth_end 2>/dev/null || true
  fi
  exit 0
fi

# --- Terminal fallback (no usable zenity/display): the original behavior. ---
notify-send -a "Second Wind" -i emblem-ok-symbolic "Second Wind" "$T_GO" 2>/dev/null || true
# --firstboot tells install.sh to skip its own logout prompt: we restart below.
# In the factory phase there is nothing to announce to the technician: install.sh
# writes system-done itself and delivery powers the machine off later. The buyer
# phases get the success stamp, which also disarms this autostart.
if [ "$PHASE" = factory ]; then
  RUN="cd '$SWDIR' && ./install.sh --firstboot --factory"
else
  RUN="cd '$SWDIR' && ./install.sh $INSTALL_ARGS && touch '$STAMP' && rm -f '$AUTOSTART'"
fi

TERMBIN="$(command -v gnome-terminal || command -v ptyxis || command -v x-terminal-emulator)"
WAITED=1
if [ -n "$TERMBIN" ]; then
  case "$(basename "$TERMBIN")" in
    gnome-terminal) "$TERMBIN" --wait -- bash -c "$RUN" ;;
    ptyxis)         "$TERMBIN" -- bash -c "$RUN"; WAITED=0 ;;  # returns immediately
    *)              "$TERMBIN" -e bash -c "$RUN" ;;
  esac
elif [ "$PHASE" = factory ]; then
  bash -c "cd '$SWDIR' && ./install.sh --firstboot --factory --yes"
else
  bash -c "cd '$SWDIR' && ./install.sh $INSTALL_ARGS --yes && touch '$STAMP' && rm -f '$AUTOSTART'"
fi

sleep 2
if [ "$PHASE" = factory ]; then
  if [ -f "$SW_ETC/system-done" ]; then
    rm -f "$AUTOSTART"; exit 0
  fi
elif [ -f "$STAMP" ]; then
  reboot_to_finish
  exit 0
fi
# Still armed after a run we actually waited for? Tell the person it resumes on
# its own (the stamp is the single source of truth).
if [ "$WAITED" = 1 ] && [ ! -f "$STAMP" ] && [ -f "$AUTOSTART" ]; then
  notify-send -a "Second Wind" -i view-refresh-symbolic "Second Wind" "$T_AGAIN" 2>/dev/null || true
fi
exit 0
