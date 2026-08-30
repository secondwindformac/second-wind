#!/usr/bin/env bash
# 55-navegadores — viste los navegadores como Mac.
# Chrome dibuja su propia ventana (por eso no muestra los botones rojo,
# amarillo y verde del tema); activando su preferencia "usar barra de título
# del sistema" pasa a usar la ventana MacTahoe con los botones a la izquierda.
# Firefox (si existe) recibe el tema oficial MacTahoe. El App Center de Ubuntu
# no se puede vestir (no usa GTK): limitación documentada en el README.

# --- Firefox (tema oficial MacTahoe) ---
if [ -d "$HOME/.mozilla/firefox" ]; then
  if [ "$DRY_RUN" = 1 ]; then
    info "HARÍA: instalar el tema MacTahoe para Firefox"
  elif ( cd "$MCL_CACHE/MacTahoe-gtk-theme" && ./tweaks.sh -f >/dev/null 2>&1 ); then
    mf note "firefox-tematizado"
    ok "Firefox vestido como Mac (reábrelo para verlo)"
  else
    warn "No se pudo aplicar el tema de Firefox"
  fi
else
  info "Firefox no está instalado; nada que hacer con él."
fi

# --- Google Chrome ---
PREFS="$HOME/.config/google-chrome/Default/Preferences"
if [ ! -f "$PREFS" ]; then
  info "Chrome no está instalado; nada que hacer con él."
elif [ "$DRY_RUN" = 1 ]; then
  info "HARÍA: activar en Chrome la barra de título del sistema (botones Mac a la izquierda)"
else
  if pgrep -x chrome >/dev/null 2>&1; then
    if ui_yesno "${MSG[preg_chrome]}" --default-no; then
      pkill -x chrome 2>/dev/null || true
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        pgrep -x chrome >/dev/null 2>&1 || break
        sleep 1
      done
    fi
  fi
  if pgrep -x chrome >/dev/null 2>&1; then
    warn "Chrome está abierto y no se puede modificar en caliente. Ciérralo y ejecuta:  ./install.sh --solo navegadores"
  else
    python3 - "$PREFS" "$MCL_STATE/chrome-prefs-antes.json" <<'PY'
import json, os, sys
prefs_p, antes_p = sys.argv[1], sys.argv[2]
with open(prefs_p) as f:
    d = json.load(f)
antes = d.get("browser", {}).get("custom_chrome_frame", "__ausente__")
if not os.path.exists(antes_p):
    with open(antes_p, "w") as f:
        json.dump({"custom_chrome_frame": antes}, f)
d.setdefault("browser", {})["custom_chrome_frame"] = False
tmp = prefs_p + ".macconlinux.tmp"
with open(tmp, "w") as f:
    json.dump(d, f)
os.replace(tmp, prefs_p)
PY
    mf note "chrome-parchado"
    ok "Chrome usará la ventana estilo Mac (botones a la izquierda) desde la próxima vez que lo abras"
  fi
fi
