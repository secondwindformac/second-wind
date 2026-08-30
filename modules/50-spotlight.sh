#!/usr/bin/env bash
# 50-spotlight — buscador con Cmd+Espacio usando Ulauncher + tema propio estilo
# Spotlight. La cadena de teclas (sin tocar Toshy):
#   Cmd+Espacio físico → Toshy emite Shift+Ctrl+Space → GNOME ejecuta ulauncher-toggle

if ! command -v ulauncher >/dev/null 2>&1; then
  warn "Ulauncher no está instalado; Spotlight queda pendiente (Etapa 1 lo instalará automáticamente)."
  return 0
fi

TDIR="$HOME/.config/ulauncher/user-themes/mactahoe-light"
SJSON="$HOME/.config/ulauncher/settings.json"
AUTOSTART="$HOME/.config/autostart/ulauncher.desktop"

if [ "$DRY_RUN" = 1 ]; then
  info "HARÍA: instalar tema Spotlight para Ulauncher, dejarlo en autoarranque y asignar Cmd+Espacio"
else
  mkdir -p "$HOME/.config/ulauncher/user-themes"
  rsync -a --delete "$MCL_ROOT/assets/ulauncher/user-themes/mactahoe-light/" "$TDIR/"
  track_new_file "$TDIR"

  if [ ! -f "$SJSON" ]; then
    cp "$MCL_ROOT/assets/ulauncher/settings.json.tpl" "$SJSON"
    track_new_file "$SJSON"
  else
    # Ya existía una configuración del usuario: solo se cambia el tema.
    python3 - "$SJSON" <<'PY'
import json, sys
p = sys.argv[1]
with open(p) as f:
    d = json.load(f)
d["theme-name"] = "mactahoe-light"
d["show-indicator-icon"] = False
with open(p, "w") as f:
    json.dump(d, f, indent=4)
PY
  fi

  if [ ! -f "$AUTOSTART" ] && [ -f /usr/share/applications/ulauncher.desktop ]; then
    cp /usr/share/applications/ulauncher.desktop "$AUTOSTART"
    track_new_file "$AUTOSTART"
  fi

  # Arrancarlo ya (bajo XWayland, como indica su propio .desktop)
  if ! pgrep -x ulauncher >/dev/null 2>&1; then
    ( setsid env GDK_BACKEND=x11 ulauncher --hide-window >/dev/null 2>&1 & ) || true
    sleep 2
  fi
fi

# Atajo: liberar Shift+Ctrl+Space de la vista general y dárselo a Ulauncher
gset_track org.gnome.shell.keybindings toggle-overview "[]"
custom_keybinding_add macconlinux-spotlight "Spotlight (Ulauncher)" "ulauncher-toggle" "<Shift><Control>space"

info "Spotlight listo: pulsa Cmd+Espacio para buscar."
