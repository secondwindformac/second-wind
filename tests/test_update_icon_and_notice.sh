#!/usr/bin/env bash
# Stub-based tests (no root, no network) for two fixes:
#   1. The ⌘ (Logo Menu) icon gets a content-hashed file name, so an update
#      writes a NEW dconf custom-icon-path; Logo Menu reloads it, no logout.
#   2. The final update notice adds a "log out and back in" line when the
#      user-level refresh still needs a logout.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(cd "$(mktemp -d)" && pwd)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
export PATH="$TMP/bin:$PATH"

fail() { echo "FAIL: $*"; exit 1; }

# ---------------------------------------------------------------------------
# 1) Icon: hashed path in dconf, old copies cleaned, plain icon still copied.
# ---------------------------------------------------------------------------
export SW_ROOT="$ROOT"
export HOME="$TMP/home"
export SW_STATE="$TMP/state"
export SW_SHARE="$TMP/share"
export SW_CACHE="$SW_STATE/cache"
export DRY_RUN=0
export LANG=en_US.UTF-8
mkdir -p "$HOME" "$SW_SHARE"
: > "$SW_SHARE/command-symbolic-white.svg"              # the old hashless name
: > "$SW_SHARE/command-symbolic-white-0123456789ab.svg" # a previous hash

export DCONF_LOG="$TMP/dconf.log"; : > "$DCONF_LOG"
cat > "$TMP/bin/dconf" <<'EOF'
#!/bin/sh
case "$1" in
  read)  : ;;
  write) printf '%s\t%s\n' "$2" "$3" >> "$DCONF_LOG" ;;
esac
EOF
cat > "$TMP/bin/gnome-extensions" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$TMP/bin/dconf" "$TMP/bin/gnome-extensions"

# shellcheck disable=SC1091
source "$ROOT/lib/common.sh"
# shellcheck disable=SC1091
source "$ROOT/versions.lock"
ext_install_pinned() { return 0; }   # no downloads
enable_extension()   { return 0; }   # no shell reload

# shellcheck disable=SC1091
source "$ROOT/modules/30-extensions.sh" >/dev/null

EXPECTED="command-symbolic-white-$(sha256sum "$ROOT/assets/command-symbolic-white.svg" | cut -c1-12).svg"
[ "$LOGO_ICON" = "$EXPECTED" ] || fail "icon name is not the content hash ($LOGO_ICON)"
[ -f "$SW_SHARE/$LOGO_ICON" ] || fail "hashed icon file was not written"
grep -q "custom-icon-path" "$DCONF_LOG" || fail "custom-icon-path was not written"
grep -qF "$SW_SHARE/$LOGO_ICON" "$DCONF_LOG" || fail "custom-icon-path does not point to the hashed file"
[ -e "$SW_SHARE/command-symbolic-white.svg" ] && fail "old hashless icon was not removed"
[ -e "$SW_SHARE/command-symbolic-white-0123456789ab.svg" ] && fail "old hashed icon was not removed"
[ -f "$SW_SHARE/command-symbolic.svg" ] || fail "plain command-symbolic.svg was not copied"

# Idempotent: a second run keeps the same path and leaves exactly one white icon.
# shellcheck disable=SC1091
source "$ROOT/modules/30-extensions.sh" >/dev/null
[ "$LOGO_ICON" = "$EXPECTED" ] || fail "icon name changed on re-run"
n="$(find "$SW_SHARE" -maxdepth 1 -type f -name 'command-symbolic-white*.svg' | wc -l)"
[ "$n" = 1 ] || fail "expected exactly one white icon, found $n"

# ---------------------------------------------------------------------------
# 2) Final notice: adds the logout line only when the refresh asks for it.
# ---------------------------------------------------------------------------
cat > "$TMP/bin/curl" <<'EOF'
#!/bin/sh
out=""; url=""; prev=""
for a in "$@"; do
  [ "$prev" = "-o" ] && out="$a"
  case "$a" in http*) url="$a" ;; esac
  prev="$a"
done
case "$url" in
  *api.github.com*)
    printf '%s\n' '{"tag_name":"v0.9.8","assets":["https://example.invalid/second-wind-0.9.8.tar.gz","https://example.invalid/SHA256SUMS"]}' ;;
  *SHA256SUMS*)
    printf '%s\n' 'deadbeef  second-wind-0.9.8.tar.gz' ;;
  *second-wind-0.9.8.tar.gz*)
    [ -n "$out" ] && printf 'payload' > "$out" ;;
esac
exit 0
EOF
cat > "$TMP/bin/sha256sum" <<'EOF'
#!/bin/sh
exit 0
EOF
cat > "$TMP/bin/pkexec" <<'EOF'
#!/bin/sh
exit 0
EOF
export NOTIFY_LOG="$TMP/notify.log"
cat > "$TMP/bin/notify-send" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$NOTIFY_LOG"
exit 0
EOF
chmod +x "$TMP/bin/curl" "$TMP/bin/sha256sum" "$TMP/bin/pkexec" "$TMP/bin/notify-send"

printf '#!/bin/bash\necho "Extensions become active after logging out and back in."\n' > "$TMP/inst-relogin.sh"
printf '#!/bin/bash\necho "Setup checks finished."\n' > "$TMP/inst-norelogin.sh"

run_manual() { # $1 = HOME, $2 = install.sh body
  local home="$1"
  rm -rf "$home"; mkdir -p "$home/.local/state/second-wind"
  mkdir -p "$TMP/managed/bin"
  cp "$ROOT/bin/second-wind-update" "$TMP/managed/bin/"
  sed -i "s|^MANAGED_ROOT=.*|MANAGED_ROOT=\"$TMP/managed\"|" "$TMP/managed/bin/second-wind-update"
  echo "0.9.6" > "$TMP/managed/VERSION"
  cp "$2" "$TMP/managed/install.sh"; chmod +x "$TMP/managed/install.sh"
  printf '#!/bin/sh\nexit 0\n' > "$TMP/managed/verify.sh"; chmod +x "$TMP/managed/verify.sh"
  : > "$NOTIFY_LOG"
  HOME="$home" LANG=en_US.UTF-8 bash "$TMP/managed/bin/second-wind-update" --manual
}

# 2a) refresh asks for a logout -> the notice says so.
run_manual "$TMP/home-a" "$TMP/inst-relogin.sh" || fail "manual update (relogin) exited nonzero"
grep -qF "Second Wind updated to version 0.9.8. All good" "$NOTIFY_LOG" \
  || fail "done notice missing"
grep -qF "To see every change, log out and back in when you can." "$NOTIFY_LOG" \
  || fail "logout line missing when the refresh asks for it"

# 2b) refresh does not ask for a logout -> the notice stays as before.
run_manual "$TMP/home-b" "$TMP/inst-norelogin.sh" || fail "manual update (no relogin) exited nonzero"
grep -qF "Second Wind updated to version 0.9.8. All good" "$NOTIFY_LOG" \
  || fail "done notice missing (no relogin)"
grep -qF "To see every change" "$NOTIFY_LOG" \
  && fail "logout line appeared when it was not needed"

bash -n "$ROOT/bin/second-wind-update" || fail "second-wind-update syntax"
bash -n "$ROOT/modules/30-extensions.sh" || fail "30-extensions syntax"

echo "PASS test_update_icon_and_notice"
