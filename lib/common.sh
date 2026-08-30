#!/usr/bin/env bash
# Second Wind — shared helpers. Sourced by install.sh / uninstall.sh / verify.sh.
# Never run as root.

SW_ROOT="${SW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SW_LIB="$SW_ROOT/lib"
SW_STATE="${SW_STATE:-$HOME/.local/state/second-wind}"
SW_SHARE="$HOME/.local/share/second-wind"
SW_CACHE="$SW_STATE/cache"
SW_BACKUP="$SW_STATE/backup/pristine"
SW_LOGDIR="$SW_STATE/logs"
export SW_MANIFEST="$SW_STATE/manifest.json"

DRY_RUN="${DRY_RUN:-0}"
ASSUME_YES="${ASSUME_YES:-0}"

# Shell chrome variant (top bar + system menus): Dark = dark translucent bar
# with white text, like the macOS menu bar over a dark dock (user-tested
# preference); apps stay light. Light is built too and can be switched to.
SW_SHELL_VARIANT="${SW_SHELL_VARIANT:-Dark}"

# One-time migration from the project's former name (MacConLinux).
if [ -d "$HOME/.local/state/macconlinux" ] && [ ! -d "$SW_STATE" ]; then
  mv "$HOME/.local/state/macconlinux" "$SW_STATE"
fi
if [ -d "$HOME/.local/share/macconlinux" ] && [ ! -d "$SW_SHARE" ]; then
  mv "$HOME/.local/share/macconlinux" "$SW_SHARE"
fi

# The installer may run from a shell without graphical session variables
# (SSH, tooling, unattended installs). Derive the essentials:
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
export DISPLAY="${DISPLAY:-:0}"
# Without TERM, vinceliuice's theme installers die inside `setterm`:
export TERM="${TERM:-xterm-256color}"

# --- output ---
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

# Run the command, or just print it in --dry-run mode.
run() {
  if [ "$DRY_RUN" = 1 ]; then printf 'DRY-RUN: %s\n' "$*"; else "$@"; fi
}

# Change manifest (no-op in dry-run).
mf() {
  [ "$DRY_RUN" = 1 ] && return 0
  python3 "$SW_LIB/manifest.py" "$@"
}

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing required tool '$1'."; }

# --- gsettings / dconf with original-value tracking ---

# gset_track SCHEMA KEY VALUE — applies only if different; records "before" once.
gset_track() {
  local schema="$1" key="$2" value="$3" cur
  if ! cur="$(gsettings get "$schema" "$key" 2>/dev/null)"; then
    warn "Key $schema $key does not exist on this system — skipped."
    return 0
  fi
  [ "$cur" = "$value" ] && return 0
  if [ "$DRY_RUN" = 1 ]; then
    printf 'DRY-RUN: gsettings set %s %s %s   (before: %s)\n' "$schema" "$key" "$value" "$cur"
    return 0
  fi
  mf record-gsettings "$schema" "$key" "$cur"
  gsettings set "$schema" "$key" "$value"
}

# dconf_track PATH VALUE — for keys whose schema is not installed yet
# (extensions before the next login).
dconf_track() {
  local path="$1" value="$2" cur
  cur="$(dconf read "$path" 2>/dev/null || true)"
  [ "$cur" = "$value" ] && return 0
  if [ "$DRY_RUN" = 1 ]; then
    printf 'DRY-RUN: dconf write %s %s   (before: %s)\n' "$path" "$value" "${cur:-<unset>}"
    return 0
  fi
  mf record-dconf "$path" "$cur"
  dconf write "$path" "$value"
}

track_new_file() { mf file-created "$1"; }

# Force gnome-shell to reload the wallpaper after its files were re-copied
# (same URI ⇒ no change event ⇒ a deleted-and-recreated file shows as black).
bg_refresh() {
  local day="$1" night="$2"
  [ "$DRY_RUN" = 1 ] && return 0
  gsettings set org.gnome.desktop.background picture-uri "'$night'" 2>/dev/null || return 0
  gsettings set org.gnome.desktop.background picture-uri "'$day'"
  gsettings set org.gnome.desktop.background picture-uri-dark "'$day'"
  gsettings set org.gnome.desktop.background picture-uri-dark "'$night'"
}

# --- downloads and pinned clones ---

# download_cached URL DEST SHA256 — reuses the cache when the checksum matches.
download_cached() {
  local url="$1" dest="$2" sha="$3"
  mkdir -p "$(dirname "$dest")"
  if [ -f "$dest" ] && printf '%s  %s\n' "$sha" "$dest" | sha256sum -c --quiet - 2>/dev/null; then
    return 0
  fi
  if [ "$DRY_RUN" = 1 ]; then printf 'DRY-RUN: download %s\n' "$url"; return 0; fi
  curl -fsSL --retry 3 -o "$dest.partial" "$url" || { warn "Could not download $url"; return 1; }
  if ! printf '%s  %s\n' "$sha" "$dest.partial" | sha256sum -c --quiet - 2>/dev/null; then
    rm -f "$dest.partial"
    warn "Download of $url does not match the expected sha256 signature. Refusing to use it."
    return 1
  fi
  mv "$dest.partial" "$dest"
}

# clone_pinned URL DIR SHA — clone (or update) and check out the exact commit.
clone_pinned() {
  local url="$1" dir="$2" sha="$3"
  if [ "$DRY_RUN" = 1 ]; then printf 'DRY-RUN: clone %s @ %s\n' "$url" "${sha:0:10}"; return 0; fi
  if [ -d "$dir/.git" ]; then
    git -C "$dir" cat-file -e "$sha^{commit}" 2>/dev/null || git -C "$dir" fetch -q origin
  else
    git clone -q "$url" "$dir" || { warn "Could not clone $url"; return 1; }
  fi
  git -C "$dir" checkout -q --detach "$sha" || { warn "Pinned commit not found in $url"; return 1; }
}

# --- GNOME extensions ---

# Idempotent merge into enabled-extensions. We avoid `gnome-extensions enable`
# because it fails for extensions the shell has not loaded yet (pre-relogin).
enable_extension() {
  local uuid="$1"
  if [ "$DRY_RUN" = 1 ]; then printf 'DRY-RUN: enable extension %s\n' "$uuid"; return 0; fi
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

# ext_install_pinned UUID TAG SHA256 — download from extensions.gnome.org,
# install at user level and enable (actually loads at next login).
ext_install_pinned() {
  local uuid="$1" tag="$2" sha="$3"
  local zip="$SW_CACHE/$uuid.shell-extension.zip"
  download_cached "https://extensions.gnome.org/download-extension/$uuid.shell-extension.zip?version_tag=$tag" \
    "$zip" "$sha" || return 1
  run gnome-extensions install --force "$zip" || return 1
  mf ext-installed "$uuid"
  enable_extension "$uuid"
}

# --- custom keybindings ---

# custom_keybinding_add ID NAME COMMAND BINDING
custom_keybinding_add() {
  local id="$1" name="$2" cmd="$3" binding="$4"
  local base="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/$id/"
  if [ "$DRY_RUN" = 1 ]; then
    printf 'DRY-RUN: custom shortcut %s → %s (%s)\n' "$binding" "$cmd" "$id"
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

# custom_keybinding_remove ID — drop one of OUR custom keybindings (migrations).
custom_keybinding_remove() {
  local id="$1"
  local base="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/$id/"
  [ "$DRY_RUN" = 1 ] && return 0
  python3 - "$base" <<'PY'
import ast, subprocess, sys
path = sys.argv[1]
out = subprocess.check_output(
    ['gsettings', 'get', 'org.gnome.settings-daemon.plugins.media-keys',
     'custom-keybindings']).decode().strip()
cur = [] if out.startswith('@as') else ast.literal_eval(out)
if path in cur:
    cur.remove(path)
    subprocess.check_call(
        ['gsettings', 'set', 'org.gnome.settings-daemon.plugins.media-keys',
         'custom-keybindings', str(cur)])
PY
  dconf reset -f "$base" 2>/dev/null || true
}

# --- language ---
# Installer strings follow the system language; English is the default.
case "${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}" in
  es*) source "$SW_LIB/i18n/es.sh" ;;
  *)   source "$SW_LIB/i18n/en.sh" ;;
esac
