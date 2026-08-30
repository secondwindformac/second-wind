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
