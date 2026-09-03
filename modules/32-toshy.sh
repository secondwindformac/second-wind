#!/usr/bin/env bash
# 32-toshy — Toshy, the Mac-style keyboard engine (⌘ per-app), pinned to the
# verified commit. Split out of 15-engines and numbered AFTER 30-extensions
# ON PURPOSE (H2b, caught by the 31-08 VM certification): Toshy's installer
# refuses a GNOME Wayland session unless a compatible shell extension is
# already installed AND enabled — and our pinned Xremap extension is put in
# place by module 30. Runs before 45-keyboard, which checks for Toshy units.

systemctl --user list-unit-files 'toshy*' 2>/dev/null | grep -q toshy && {
  ok "Toshy OK"
  return 0
}

if [ "$DRY_RUN" = 1 ]; then
  info "${MSG[m15_dry]}"
  return 0
fi

info "${MSG[m60_sudo]}"
if ! sw_sudo_ready; then
  warn "${MSG[m15_no_sudo]}"
  return 1
fi
# Keep sudo warm: a slow Toshy build can outlive the 15-minute timestamp.
( while sleep 50; do sudo -n true 2>/dev/null || exit; done ) &
SW_TOSHY_KEEPALIVE=$!
trap 'kill "$SW_TOSHY_KEEPALIVE" 2>/dev/null || true; sudo -n rm -f /etc/sudoers.d/zz-second-wind-toshy 2>/dev/null || true' EXIT

info "${MSG[m15_toshy]}"
# H2 (31-08 certification): Toshy's installer resets sudo (sudo -k) and
# prompts for the password mid-run — inside firstboot's pipeline that prompt
# fights the tty and the install dies mute at the 15-minute timeout. Toshy
# therefore runs UNATTENDED: a temporary NOPASSWD drop-in (the person already
# proved the password to start this install) covers its internal sudo, and
# `yes` feeds its [y/n] prompts. The drop-in is removed right after the
# attempt — and again in the EXIT trap above, belt and suspenders.
SW_SUDO_DROPIN=/etc/sudoers.d/zz-second-wind-toshy
printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$(id -un)" | sudo tee "$SW_SUDO_DROPIN" >/dev/null
sudo chmod 0440 "$SW_SUDO_DROPIN"
if ! sudo visudo -c -q -f "$SW_SUDO_DROPIN" 2>/dev/null; then
  sudo rm -f "$SW_SUDO_DROPIN"; SW_SUDO_DROPIN=""
fi

# H2b: Toshy asks the RUNNING shell for enabled extensions
# (`gnome-extensions list --enabled`), and a running shell cannot see a
# just-installed extension until relogin — so at firstboot it would demand a
# typed secret code and die. This shim, first in PATH only for Toshy's run,
# answers `list` truthfully from gsettings instead (where module 30 really
# did enable Xremap; it loads on the relogin our installer already requires).
SW_TOSHY_SHIM="$(mktemp -d)"
cat > "$SW_TOSHY_SHIM/gnome-extensions" <<'EOSH'
#!/bin/sh
if [ "$1" = "list" ]; then
  gsettings get org.gnome.shell enabled-extensions \
    | tr -d "[]'" | tr ',' '\n' | sed 's/^ *//; /^$/d'
  exit 0
fi
exec /usr/bin/gnome-extensions "$@"
EOSH
chmod +x "$SW_TOSHY_SHIM/gnome-extensions"

TOSHY_RUN() {
  cd "$SW_CACHE/toshy" && export PATH="$SW_TOSHY_SHIM:$HOME/.local/bin:$PATH"
  # PIPESTATUS[1]: under pipefail, `yes` dying of SIGPIPE (141) must not
  # count as a Toshy failure — the installer's own exit code decides.
  if ui_has_tty; then
    info "${MSG[m15_toshy_tty]}"
    yes | timeout 900 python3 setup_toshy.py install 2>&1 | tee -a "$SW_LOGDIR/toshy-install.log"
    return "${PIPESTATUS[1]}"
  else
    yes | timeout 900 python3 setup_toshy.py install >>"$SW_LOGDIR/toshy-install.log" 2>&1
    return "${PIPESTATUS[1]}"
  fi
}
if clone_pinned "$TOSHY_REPO" "$SW_CACHE/toshy" "$TOSHY_SHA" && ( TOSHY_RUN ); then
  if systemctl --user list-unit-files 'toshy*' 2>/dev/null | grep -q toshy; then
    mf note "toshy-installed-by-secondwind"
    export HAVE_TOSHY=1
    ok "Toshy OK"
  else
    warn "${MSG[m15_toshy_err]}"
  fi
else
  warn "${MSG[m15_toshy_err]}"
fi

# Hide Toshy's technical menu entries (same rationale as 15-engines: the
# person never chose "Toshy"; the features keep working via services).
# 15-engines defines hide_desktop_entry but may have returned early on
# machines where its engines were already present — define a fallback.
type hide_desktop_entry >/dev/null 2>&1 || hide_desktop_entry() {
  local f="$1"
  [ -f "$f" ] || return 0
  if grep -q '^NoDisplay=' "$f"; then
    sed -i 's/^NoDisplay=.*/NoDisplay=true/' "$f"
  else
    printf 'NoDisplay=true\n' >> "$f"
  fi
}
hide_desktop_entry "$HOME/.local/share/applications/app.toshy.preferences.desktop"
hide_desktop_entry "$HOME/.local/share/applications/Toshy_Tray.desktop"

rm -rf "$SW_TOSHY_SHIM"
[ -n "${SW_SUDO_DROPIN:-}" ] && sudo rm -f "$SW_SUDO_DROPIN" || true
kill "$SW_TOSHY_KEEPALIVE" 2>/dev/null || true
trap - EXIT
