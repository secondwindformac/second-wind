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

ATTEMPT_FILE="$SW_STATE/firstboot-attempt"
ATTEMPT=$(( $(cat "$ATTEMPT_FILE" 2>/dev/null || echo 0) + 1 ))
echo "$ATTEMPT" > "$ATTEMPT_FILE"

case "${LANG:-en}" in
  es*)
    T_NET="Conéctate a internet para terminar de convertir tu Mac (WiFi arriba a la derecha, o comparte internet del teléfono por cable USB)."
    T_GO="Segundos… abriendo el instalador de Second Wind. No apagues el Mac durante estos minutos."
    T_RETRY="Retomando la preparación de tu Mac donde quedó — no se perdió nada."
    T_AGAIN="La preparación quedó a medias. Al próximo inicio de sesión se retoma sola; no se perdió nada."
    T_DONE="¡Casi listo! Reiniciamos tu Mac para aplicar los últimos toques. Vuelve a iniciar sesión y ya estará."
    ;;
  *)
    T_NET="Connect to the internet to finish turning this into a Mac (WiFi at the top right, or USB-tether your phone)."
    T_GO="Seconds… opening the Second Wind installer. Don't turn the Mac off during these minutes."
    T_RETRY="Picking up your Mac's preparation where it stopped — nothing was lost."
    T_AGAIN="The preparation stopped halfway. It resumes by itself at your next login; nothing was lost."
    T_DONE="Almost there! Restarting your Mac to apply the final touches. Log back in and it's ready."
    ;;
esac

# Give the desktop a moment to settle
sleep 15

if [ "$ATTEMPT" -gt 1 ]; then
  notify-send -i view-refresh-symbolic "Second Wind" "$T_RETRY" 2>/dev/null || true
fi

# Wait for connectivity, reminding gently. Never depend on curl alone:
# a stock Ubuntu Desktop install ships without it (VM-rehearsal lesson).
net_ok() {
  nm-online -q -t 15 2>/dev/null && return 0
  ping -c1 -W3 archive.ubuntu.com >/dev/null 2>&1 && return 0
  command -v curl >/dev/null 2>&1 && curl -fsI -m 5 https://extensions.gnome.org >/dev/null 2>&1
}
until net_ok; do
  notify-send -i network-wireless "Second Wind" "$T_NET" 2>/dev/null || true
  sleep 40
done
notify-send -i emblem-ok-symbolic "Second Wind" "$T_GO" 2>/dev/null || true

# The wrapped run disarms the autostart ONLY after install.sh exits happily.
# --firstboot tells install.sh to skip its own logout prompt: we restart below.
RUN="cd '$SWDIR' && ./install.sh --firstboot && touch '$STAMP' && rm -f '$AUTOSTART'"

TERMBIN="$(command -v gnome-terminal || command -v ptyxis || command -v x-terminal-emulator)"
WAITED=1
if [ -n "$TERMBIN" ]; then
  case "$(basename "$TERMBIN")" in
    gnome-terminal) "$TERMBIN" --wait -- bash -c "$RUN" ;;
    ptyxis)         "$TERMBIN" -- bash -c "$RUN"; WAITED=0 ;;  # returns immediately
    *)              "$TERMBIN" -e bash -c "$RUN" ;;
  esac
else
  bash -c "cd '$SWDIR' && ./install.sh --firstboot --yes && touch '$STAMP' && rm -f '$AUTOSTART'"
fi

sleep 2

# Success (STAMP present ⇒ install finished, autostart already disarmed above)?
# The GNOME extensions we just installed only take effect in a FRESH shell:
# THIS session's gnome-shell started before they existed on disk and never
# rescanned them, so the top bar stays Ubuntu's until a new shell starts. One
# reboot finishes the conversion (and boots the freshly-installed GA kernel).
# The stamp is set and the autostart removed, so this fires exactly once and
# never loops. (ptyxis returns immediately ⇒ STAMP not yet written ⇒ no reboot;
# gnome-terminal, Ubuntu's default, waits — see WAITED.)
if [ -f "$STAMP" ]; then
  notify-send -i emblem-ok-symbolic "Second Wind" "$T_DONE" 2>/dev/null || true
  sleep 6
  gnome-session-quit --reboot --no-prompt 2>/dev/null \
    || systemctl reboot 2>/dev/null \
    || sudo -n systemctl reboot 2>/dev/null \
    || true
  exit 0
fi

# Still armed after a run we actually waited for? Tell the person it will
# resume on its own (the stamp is the single source of truth).
if [ "$WAITED" = 1 ] && [ ! -f "$STAMP" ] && [ -f "$AUTOSTART" ]; then
  notify-send -i view-refresh-symbolic "Second Wind" "$T_AGAIN" 2>/dev/null || true
fi
exit 0
