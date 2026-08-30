#!/usr/bin/env bash
# MacConLinux — arranque en una línea (cuando el repositorio sea público):
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/USUARIO/MacConLinux/main/get.sh)"
# Descarga el repositorio completo y ejecuta el instalador local (conserva la terminal).
set -euo pipefail

REPO="${MACCONLINUX_REPO:-https://github.com/USUARIO/MacConLinux.git}"   # se fija al publicar
REF="${MACCONLINUX_REF:-main}"                                            # usar un tag estable al publicar
DEST="$HOME/.local/share/macconlinux/app"

command -v git >/dev/null 2>&1 || {
  echo "Falta git. Instálalo con:  sudo apt install -y git"
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
