#!/usr/bin/env bash
# 90-postlogin — deja programada una verificación de UN SOLO USO para el
# próximo inicio de sesión: comprueba que todo quedó bien y avisa con una
# notificación. Después se borra sola.

if [ "$DRY_RUN" = 1 ]; then
  info "HARÍA: programar la verificación automática del próximo inicio de sesión"
  return 0
fi

POSTLOGIN="$MCL_STATE/postlogin.sh"
AUTOSTART="$HOME/.config/autostart/macconlinux-postinstall.desktop"

cat > "$POSTLOGIN" <<EOF
#!/usr/bin/env bash
# MacConLinux: verificación única tras el primer inicio de sesión (se autoelimina).
sleep 20
if "$MCL_ROOT/verify.sh" --rapido >/dev/null 2>&1; then
  notify-send -i preferences-desktop-theme "MacConLinux" "¡Listo! Tu escritorio ya es tipo macOS. Pulsa Cmd+Espacio para buscar." 2>/dev/null || true
else
  notify-send -i dialog-warning "MacConLinux" "Instalación aplicada, con algún detalle pendiente. Ejecuta ./verify.sh en la carpeta MacConLinux para ver cuál." 2>/dev/null || true
fi
rm -f "$AUTOSTART"
rm -f "$POSTLOGIN"
EOF
chmod +x "$POSTLOGIN"
track_new_file "$POSTLOGIN"

mkdir -p "$HOME/.config/autostart"
sed "s|@POSTLOGIN@|$POSTLOGIN|" "$MCL_ROOT/assets/autostart/macconlinux-postinstall.desktop.tpl" > "$AUTOSTART"
track_new_file "$AUTOSTART"
