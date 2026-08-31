#!/usr/bin/env bash
# Second Wind — installation state verification.
# Usage: ./verify.sh [--all | --quick]
#   --quick  instant checks only (used right after login)
#   --all    everything, including checks that need a post-install re-login (default)
# (Spanish aliases: --todo = --all, --rapido = --quick)
set -uo pipefail
cd "$(dirname "$0")"
SW_ROOT="$(pwd)"
source lib/common.sh
source versions.lock

MODE="${1:---all}"
case "$MODE" in --todo) MODE=--all ;; --rapido) MODE=--quick ;; esac

PASS=0
FAIL=0

chk() {
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then
    PASS=$((PASS + 1)); printf '%s %s\n' "${C_OK}✔${C_OFF}" "$d"
  else
    FAIL=$((FAIL + 1)); printf '%s %s\n' "${C_ERR}✖${C_OFF}" "$d"
  fi
}
eq() { [ "$(gsettings get "$1" "$2" 2>/dev/null)" = "$3" ]; }

echo "${MSG[v_sec_look]}"
chk "${MSG[v_gtk]}"           eq org.gnome.desktop.interface gtk-theme "'MacTahoe-Light-solid'"
chk "${MSG[v_icons]}"         eq org.gnome.desktop.interface icon-theme "'MacTahoe'"
chk "${MSG[v_cursor]}"        eq org.gnome.desktop.interface cursor-theme "'MacTahoe-cursors'"
chk "${MSG[v_font]}"          eq org.gnome.desktop.interface font-name "'Inter 11'"
chk "${MSG[v_theme_dir]}"     test -d "$HOME/.themes/MacTahoe-Light-solid/gnome-shell"
chk "${MSG[v_theme_derived]}" test -d "$HOME/.themes/SecondWind-$SW_SHELL_VARIANT/gnome-shell"
chk "${MSG[v_font_files]}"    test -f "$HOME/.local/share/fonts/Inter/Inter-Regular.ttf"
chk "${MSG[v_wallp]}"         test -f "$HOME/.local/share/backgrounds/MacTahoe/MacTahoe-day.jpeg"
chk "${MSG[v_libadw]}"        test -f "$HOME/.config/gtk-4.0/gtk.css"

echo "${MSG[v_sec_dock]}"
chk "${MSG[v_dock_float]}"    eq org.gnome.shell.extensions.dash-to-dock extend-height "false"
chk "${MSG[v_dock_48]}"       eq org.gnome.shell.extensions.dash-to-dock dash-max-icon-size "48"
chk "${MSG[v_btns_left]}"     eq org.gnome.desktop.wm.preferences button-layout "'close,minimize,maximize:'"
chk "${MSG[v_hotcorner]}"     eq org.gnome.desktop.interface enable-hot-corners "true"
chk "${MSG[v_center]}"        eq org.gnome.mutter center-new-windows "true"

echo "${MSG[v_sec_kbd]}"
chk "${MSG[v_xkb]}"           eq org.gnome.desktop.input-sources xkb-options "@as []"
chk "${MSG[v_cmdtab_all]}"    eq org.gnome.shell.app-switcher current-workspace-only "false"
chk "${MSG[v_cmdtab_uni]}"    bash -c "gsettings get org.gnome.desktop.wm.keybindings switch-applications | grep -q '<Alt>Tab'"
chk "${MSG[v_lowbat]}"        eq org.gnome.settings-daemon.plugins.power power-saver-profile-on-low-battery "true"
# The Experience layer (⌘ keyboard, Spotlight, ⌘Tab) is stateful: trial and
# active mean ON; off (day-30, unlicensed) means the OPPOSITE must hold.
EXP_STATE="$("$SW_ROOT/bin/second-wind-experience" status 2>/dev/null | cut -d' ' -f1)"
EXP_STATE="${EXP_STATE:-trial}"
if [ "$EXP_STATE" = "off" ]; then
  chk "${MSG[v_exp]}" bash -c '! systemctl --user is-active toshy-config.service >/dev/null 2>&1 \
    && ! pgrep -x ulauncher >/dev/null 2>&1 \
    && ! gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings | grep -q secondwind-spotlight \
    && gsettings get org.gnome.desktop.wm.keybindings switch-windows | grep -q "<Alt>Tab"'
else
  chk "${MSG[v_toshy]}"         systemctl --user is-active toshy-config.service
  chk "${MSG[v_ul_run]}"        pgrep -x ulauncher
  chk "${MSG[v_spot_key]}"      bash -c "gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings | grep -q secondwind-spotlight"
fi
chk "${MSG[v_tray]}"          bash -c '! test -e "$HOME/.config/autostart/Toshy_Tray.desktop"'
chk "${MSG[v_overview_free]}" eq org.gnome.shell.keybindings toggle-overview "@as []"
chk "${MSG[store_name]}"      test -f "$HOME/.local/share/applications/second-wind-apps.desktop"

if [ "$MODE" = "--all" ]; then
  echo "${MSG[v_sec_ext]}"
  for uuid in "$EXT_USER_THEME_UUID" "$EXT_BMS_UUID" "$EXT_XREMAP_UUID" "$EXT_LOGO_UUID"; do
    chk "${MSG[v_ext_active]} ${uuid%%@*}" bash -c "LC_ALL=C gnome-extensions info '$uuid' 2>/dev/null | grep -qE 'State: (ACTIVE|ENABLED)'"
  done
  chk "${MSG[v_panel_theme]}"  bash -c "[ \"\$(dconf read /org/gnome/shell/extensions/user-theme/name)\" = \"'SecondWind-$SW_SHELL_VARIANT'\" ]"
  chk "${MSG[v_xremap_dbus]}"  busctl --user introspect org.gnome.Shell /com/k0kubun/Xremap

  echo "${MSG[v_sec_brow]}"
  if python3 lib/manifest.py has-note "chrome-patched" 2>/dev/null; then
    chk "${MSG[v_chrome]}" bash -c "python3 -c \"import json;d=json.load(open('$HOME/.config/google-chrome/Default/Preferences'));exit(0 if d.get('browser',{}).get('custom_chrome_frame') is False else 1)\""
  else
    echo "${MSG[v_chrome_pending]}"
  fi
  if python3 lib/manifest.py has-note "gdm-installed" 2>/dev/null; then
    chk "${MSG[v_gdm]}" test -f "/usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource.bak"
  else
    echo "${MSG[v_gdm_pending]}"
  fi

  echo "${MSG[v_sec_hw]}"
  HWCONF="$(ls /etc/modprobe.d/secondwind-hid_apple.conf /etc/modprobe.d/macconlinux-hid_apple.conf 2>/dev/null | head -1)"
  if [ -n "$HWCONF" ]; then
    chk "${MSG[v_mbpfan]}" systemctl is-active mbpfan
    chk "${MSG[v_fnmode]}" bash -c "grep -q \"fnmode=\$(cat /sys/module/hid_apple/parameters/fnmode)\" '$HWCONF'"
    chk "${MSG[v_cam]}"    test -e /dev/video0
  else
    echo "${MSG[v_hw_none]}"
  fi
  if command -v vainfo >/dev/null 2>&1; then
    chk "${MSG[v_vaapi]}" bash -c "vainfo 2>/dev/null | grep -qiE 'H264|AVC'"
  fi
  if [ -f /etc/systemd/logind.conf.d/secondwind.conf ]; then
    chk "${MSG[v_hib]}" bash -c "grep -q suspend-then-hibernate /etc/systemd/logind.conf.d/secondwind.conf && grep -q 'resume=' /etc/default/grub.d/secondwind-hibernate.cfg"
  fi
  chk "${MSG[v_thermald]}" systemctl is-active thermald
fi

echo
if [ "$FAIL" -eq 0 ]; then
  ok "${MSG[v_result]} $PASS ${MSG[v_ok_all]}"
else
  warn "${MSG[v_result]} $PASS ${MSG[v_passed]} $FAIL ${MSG[v_some_bad]}"
fi
[ "$FAIL" -eq 0 ]
