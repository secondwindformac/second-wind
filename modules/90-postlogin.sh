#!/usr/bin/env bash
# 90-postlogin — schedules a ONE-TIME verification for the next login: checks
# that everything landed well and notifies the user. Then it deletes itself.

if [ "$DRY_RUN" = 1 ]; then
  info "${MSG[m90_dry]}"
  return 0
fi

POSTLOGIN="$SW_STATE/postlogin.sh"
AUTOSTART="$HOME/.config/autostart/secondwind-postinstall.desktop"
# pre-rename leftover
rm -f "$HOME/.config/autostart/macconlinux-postinstall.desktop"

cat > "$POSTLOGIN" <<EOF
#!/usr/bin/env bash
# Second Wind: one-time verification after the first login (self-deleting).
sleep 20

# Force-activate our GNOME extensions. On a TRULY clean install, gnome-shell
# does not reliably auto-enable freshly-installed user extensions on the FIRST
# post-install login: they sit on disk and in enabled-extensions, yet inactive
# until a later shell start (a known GNOME 46 / Wayland first-login quirk).
# The installer runs while the old shell is up, so it cannot activate them
# there. THIS login's shell has already rescanned the extensions directory, so
# an explicit enable turns them on live — no need to ask the person to log in a
# second time. Without this the Mac top bar (panel theme + ⌘/logo menu) and the
# per-app keys stay in Ubuntu's default look. Idempotent: a no-op where the
# shell already enabled them.
gsettings set org.gnome.shell disable-user-extensions false 2>/dev/null || true
for uuid in $EXT_USER_THEME_UUID $EXT_BMS_UUID $EXT_XREMAP_UUID $EXT_LOGO_UUID; do
  gnome-extensions enable "\$uuid" 2>/dev/null || true
done
sleep 3

if "$SW_ROOT/verify.sh" --quick >/dev/null 2>&1; then
  notify-send -i preferences-desktop-theme "Second Wind" "${MSG[notify_ok]}" 2>/dev/null || true
else
  notify-send -i dialog-warning "Second Wind" "${MSG[notify_warn]}" 2>/dev/null || true
fi
rm -f "$AUTOSTART"
rm -f "$POSTLOGIN"
EOF
chmod +x "$POSTLOGIN"
track_new_file "$POSTLOGIN"

mkdir -p "$HOME/.config/autostart"
sed "s|@POSTLOGIN@|$POSTLOGIN|" "$SW_ROOT/assets/autostart/secondwind-postinstall.desktop.tpl" > "$AUTOSTART"
track_new_file "$AUTOSTART"
