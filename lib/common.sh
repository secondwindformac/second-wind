#!/usr/bin/env bash
# MacConLinux — funciones compartidas. Se carga con `source` desde
# install.sh / uninstall.sh / verify.sh. Nunca ejecutar como root.

MCL_ROOT="${MCL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MCL_LIB="$MCL_ROOT/lib"
MCL_STATE="${MCL_STATE:-$HOME/.local/state/macconlinux}"
MCL_CACHE="$MCL_STATE/cache"
MCL_BACKUP="$MCL_STATE/backup/pristine"
MCL_LOGDIR="$MCL_STATE/logs"
export MCL_MANIFEST="$MCL_STATE/manifest.json"

DRY_RUN="${DRY_RUN:-0}"
ASSUME_YES="${ASSUME_YES:-0}"

# El instalador puede correr desde un shell sin variables de sesión gráfica
# (SSH, herramientas, instalación desatendida). Derivamos las imprescindibles:
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
export DISPLAY="${DISPLAY:-:0}"
# Sin TERM, los instaladores de temas de vinceliuice mueren en `setterm`:
export TERM="${TERM:-xterm-256color}"

# --- salida ---
if [ -t 1 ]; then
  C_OK=$'\033[1;32m'; C_WARN=$'\033[1;33m'; C_ERR=$'\033[1;31m'
  C_INFO=$'\033[1;36m'; C_OFF=$'\033[0m'
else
  C_OK=""; C_WARN=""; C_ERR=""; C_INFO=""; C_OFF=""
fi
info() { printf '%s\n' "${C_INFO}» $*${C_OFF}"; }
ok()   { printf '%s\n' "${C_OK}✔ $*${C_OFF}"; }
warn() { printf '%s\n' "${C_WARN}⚠ $*${C_OFF}"; }
die()  { printf '%s\n' "${C_ERR}✖ $*${C_OFF}" >&2; exit 1; }

# Ejecuta el comando, o en modo --dry-run solo muestra qué haría.
run() {
  if [ "$DRY_RUN" = 1 ]; then printf 'HARÍA: %s\n' "$*"; else "$@"; fi
}

# Manifiesto de cambios (silencioso en dry-run).
mf() {
  [ "$DRY_RUN" = 1 ] && return 0
  python3 "$MCL_LIB/manifest.py" "$@"
}

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Falta la herramienta '$1'."; }

# --- gsettings / dconf con registro del valor original ---

# gset_track SCHEMA CLAVE VALOR — aplica solo si difiere; registra el "antes" una vez.
gset_track() {
  local schema="$1" key="$2" value="$3" cur
  if ! cur="$(gsettings get "$schema" "$key" 2>/dev/null)"; then
    warn "No existe la clave $schema $key en este sistema — se omite."
    return 0
  fi
  [ "$cur" = "$value" ] && return 0
  if [ "$DRY_RUN" = 1 ]; then
    printf 'HARÍA: gsettings set %s %s %s   (antes: %s)\n' "$schema" "$key" "$value" "$cur"
    return 0
  fi
  mf record-gsettings "$schema" "$key" "$cur"
  gsettings set "$schema" "$key" "$value"
}

# dconf_track RUTA VALOR — para claves sin schema instalado aún (extensiones pre-relogin).
dconf_track() {
  local path="$1" value="$2" cur
  cur="$(dconf read "$path" 2>/dev/null || true)"
  [ "$cur" = "$value" ] && return 0
  if [ "$DRY_RUN" = 1 ]; then
    printf 'HARÍA: dconf write %s %s   (antes: %s)\n' "$path" "$value" "${cur:-<sin valor>}"
    return 0
  fi
  mf record-dconf "$path" "$cur"
  dconf write "$path" "$value"
}

track_new_file() { mf file-created "$1"; }

# --- descargas y clones pineados ---

# download_cached URL DESTINO SHA256 — reutiliza el caché si la firma coincide.
download_cached() {
  local url="$1" dest="$2" sha="$3"
  mkdir -p "$(dirname "$dest")"
  if [ -f "$dest" ] && printf '%s  %s\n' "$sha" "$dest" | sha256sum -c --quiet - 2>/dev/null; then
    return 0
  fi
  if [ "$DRY_RUN" = 1 ]; then printf 'HARÍA: descargar %s\n' "$url"; return 0; fi
  curl -fsSL --retry 3 -o "$dest.parcial" "$url" || { warn "No se pudo descargar $url"; return 1; }
  if ! printf '%s  %s\n' "$sha" "$dest.parcial" | sha256sum -c --quiet - 2>/dev/null; then
    rm -f "$dest.parcial"
    warn "La descarga de $url no coincide con la firma esperada (sha256). Por seguridad no se usará."
    return 1
  fi
  mv "$dest.parcial" "$dest"
}

# clone_pinned URL DIR SHA — clona (o actualiza) y fija el commit exacto.
clone_pinned() {
  local url="$1" dir="$2" sha="$3"
  if [ "$DRY_RUN" = 1 ]; then printf 'HARÍA: clonar %s @ %s\n' "$url" "${sha:0:10}"; return 0; fi
  if [ -d "$dir/.git" ]; then
    git -C "$dir" cat-file -e "$sha^{commit}" 2>/dev/null || git -C "$dir" fetch -q origin
  else
    git clone -q "$url" "$dir" || { warn "No se pudo clonar $url"; return 1; }
  fi
  git -C "$dir" checkout -q --detach "$sha" || { warn "No existe el commit pineado en $url"; return 1; }
}

# --- extensiones GNOME ---

# Merge idempotente en enabled-extensions. No usamos `gnome-extensions enable`
# porque falla con extensiones que el shell aún no cargó (pre-relogin).
enable_extension() {
  local uuid="$1"
  if [ "$DRY_RUN" = 1 ]; then printf 'HARÍA: habilitar extensión %s\n' "$uuid"; return 0; fi
  python3 - "$uuid" <<'PY'
import ast, subprocess, sys
uuid = sys.argv[1]
out = subprocess.check_output(
    ['gsettings', 'get', 'org.gnome.shell', 'enabled-extensions']).decode().strip()
cur = [] if out.startswith('@as') else ast.literal_eval(out)
if uuid not in cur:
    cur.append(uuid)
    subprocess.check_call(
        ['gsettings', 'set', 'org.gnome.shell', 'enabled-extensions', str(cur)])
PY
}

# ext_install_pinned UUID TAG SHA256 — descarga desde extensions.gnome.org,
# instala a nivel usuario y habilita (carga real: al cerrar sesión).
ext_install_pinned() {
  local uuid="$1" tag="$2" sha="$3"
  local zip="$MCL_CACHE/$uuid.shell-extension.zip"
  download_cached "https://extensions.gnome.org/download-extension/$uuid.shell-extension.zip?version_tag=$tag" \
    "$zip" "$sha" || return 1
  run gnome-extensions install --force "$zip" || return 1
  mf ext-installed "$uuid"
  enable_extension "$uuid"
}

# --- atajos personalizados ---

# custom_keybinding_add ID NOMBRE COMANDO ATAJO
custom_keybinding_add() {
  local id="$1" name="$2" cmd="$3" binding="$4"
  local base="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/$id/"
  if [ "$DRY_RUN" = 1 ]; then
    printf 'HARÍA: atajo personalizado %s → %s (%s)\n' "$binding" "$cmd" "$id"
    return 0
  fi
  local cur
  cur="$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)"
  mf record-gsettings org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$cur"
  mf record-dconf "$base" ""
  python3 - "$base" <<'PY'
import ast, subprocess, sys
path = sys.argv[1]
out = subprocess.check_output(
    ['gsettings', 'get', 'org.gnome.settings-daemon.plugins.media-keys',
     'custom-keybindings']).decode().strip()
cur = [] if out.startswith('@as') else ast.literal_eval(out)
if path not in cur:
    cur.append(path)
    subprocess.check_call(
        ['gsettings', 'set', 'org.gnome.settings-daemon.plugins.media-keys',
         'custom-keybindings', str(cur)])
PY
  local schema="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$base"
  gsettings set "$schema" name "$name"
  gsettings set "$schema" command "$cmd"
  gsettings set "$schema" binding "$binding"
}
