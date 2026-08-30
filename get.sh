#!/usr/bin/env bash
# Second Wind — one-line bootstrap (once the repository is public):
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/USER/second-wind/main/get.sh)"
# Downloads the full repository and runs the local installer (keeps the TTY).
set -euo pipefail

REPO="${SECOND_WIND_REPO:-https://github.com/USER/second-wind.git}"   # set at publish time
REF="${SECOND_WIND_REF:-main}"                                        # use a stable tag when released
DEST="$HOME/.local/share/second-wind/app"

command -v git >/dev/null 2>&1 || {
  echo "git is missing. Install it with:  sudo apt install -y git"
  exit 1
}

if [ -d "$DEST/.git" ]; then
  git -C "$DEST" fetch -q origin "$REF" && git -C "$DEST" checkout -q "$REF" \
    && git -C "$DEST" pull -q --ff-only origin "$REF" 2>/dev/null || true
else
  mkdir -p "$(dirname "$DEST")"
  git clone -q --depth 1 --branch "$REF" "$REPO" "$DEST"
fi

exec "$DEST/install.sh" "$@"
