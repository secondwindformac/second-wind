#!/bin/bash
# Second Wind — first-login bootstrap, installed by the USB autoinstaller.
# Waits for internet, then opens the regular Second Wind installer in a
# terminal (one confirmation + the user's password for the admin steps).
# Self-disarms after launching; the installer itself is idempotent.

SWDIR=/usr/local/share/second-wind
LOGDIR="$HOME/.local/state/second-wind/logs"
mkdir -p "$LOGDIR"
exec >>"$LOGDIR/firstboot.log" 2>&1
echo "=== firstboot $(date -Is) ==="

[ -x "$SWDIR/install.sh" ] || { echo "second-wind payload missing"; exit 0; }

case "${LANG:-en}" in
  es*)
    T_NET="Conéctate a internet para terminar de convertir tu Mac (WiFi arriba a la derecha, o comparte internet del teléfono por cable USB)."
    T_GO="Segundos… abriendo el instalador de Second Wind."
    ;;
  *)
    T_NET="Connect to the internet to finish turning this into a Mac (WiFi at the top right, or USB-tether your phone)."
    T_GO="Seconds… opening the Second Wind installer."
    ;;
esac

# Give the desktop a moment to settle
sleep 15

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

# Disarm the autostart (one shot; reruns are manual and idempotent)
rm -f "$HOME/.config/autostart/second-wind-firstboot.desktop"

TERMBIN="$(command -v gnome-terminal || command -v ptyxis || command -v x-terminal-emulator)"
if [ -n "$TERMBIN" ]; then
  case "$(basename "$TERMBIN")" in
    gnome-terminal) exec "$TERMBIN" --wait -- bash -c "cd '$SWDIR' && ./install.sh" ;;
    ptyxis)         exec "$TERMBIN" -- bash -c "cd '$SWDIR' && ./install.sh" ;;
    *)              exec "$TERMBIN" -e bash -c "cd '$SWDIR' && ./install.sh" ;;
  esac
else
  cd "$SWDIR" && ./install.sh --yes
fi
