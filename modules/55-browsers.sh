#!/usr/bin/env bash
# 55-browsers — dresses the browsers like a Mac.
# Chrome draws its own window frame (that's why it lacks the theme's red,
# yellow and green buttons); enabling its "use system title bar" preference
# switches it to the MacTahoe window with left-side buttons.
# Firefox (if present) gets the official MacTahoe theme. Ubuntu's App Center
# cannot be themed (it does not use GTK): documented limitation in the README.

# --- Firefox (official MacTahoe theme) ---
if [ -d "$HOME/.mozilla/firefox" ]; then
  if [ "$DRY_RUN" = 1 ]; then
    info "${MSG[m55_ff_dry]}"
  elif ( cd "$SW_CACHE/MacTahoe-gtk-theme" && ./tweaks.sh -f >/dev/null 2>&1 ); then
    mf note "firefox-themed"
    ok "${MSG[m55_ff_ok]}"
  else
    warn "${MSG[m55_ff_err]}"
  fi
else
  info "${MSG[m55_no_ff]}"
fi

# --- Google Chrome ---
PREFS="$HOME/.config/google-chrome/Default/Preferences"
if [ ! -f "$PREFS" ]; then
  info "${MSG[m55_no_chrome]}"
elif [ "$DRY_RUN" = 1 ]; then
  info "${MSG[m55_chrome_dry]}"
else
  if pgrep -x chrome >/dev/null 2>&1; then
    if ui_yesno "${MSG[ask_chrome]}" --default-no; then
      pkill -x chrome 2>/dev/null || true
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        pgrep -x chrome >/dev/null 2>&1 || break
        sleep 1
      done
    fi
  fi
  if pgrep -x chrome >/dev/null 2>&1; then
    warn "${MSG[m55_chrome_open]}"
  else
    python3 - "$PREFS" "$SW_STATE/chrome-prefs-before.json" <<'PY'
import json, os, sys
prefs_p, before_p = sys.argv[1], sys.argv[2]
with open(prefs_p) as f:
    d = json.load(f)
before = d.get("browser", {}).get("custom_chrome_frame", "__absent__")
# migrate the pre-rename record if present
old_p = before_p.replace("chrome-prefs-before.json", "chrome-prefs-antes.json")
if os.path.exists(old_p) and not os.path.exists(before_p):
    os.replace(old_p, before_p)
if not os.path.exists(before_p):
    with open(before_p, "w") as f:
        json.dump({"custom_chrome_frame": before}, f)
d.setdefault("browser", {})["custom_chrome_frame"] = False
tmp = prefs_p + ".secondwind.tmp"
with open(tmp, "w") as f:
    json.dump(d, f)
os.replace(tmp, prefs_p)
PY
    mf note "chrome-patched"
    ok "${MSG[m55_chrome_ok]}"
  fi
fi
