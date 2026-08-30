#!/usr/bin/env bash
# Publica MacConLinux en GitHub como repositorio PRIVADO del usuario.
# Paso de desarrollador (no forma parte del instalador).
# Requiere: contraseña de administrador (para instalar GitHub CLI la primera
# vez) y completar el inicio de sesión de GitHub en el navegador.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v gh >/dev/null 2>&1; then
  echo "» Instalando GitHub CLI (pedirá tu contraseña de administrador)…"
  sudo apt-get update -qq
  sudo apt-get install -y gh
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "» Inicia sesión en GitHub (se abrirá tu navegador; sigue los pasos)…"
  gh auth login --web --git-protocol https
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "» Creando el repositorio privado MacConLinux en tu cuenta…"
  gh repo create MacConLinux --private --source=. --remote=origin \
    --description "Experiencia macOS one-click para Ubuntu en Macs sin soporte de Apple"
fi

git push -u origin main
echo
echo "✔ Publicado en privado: $(gh repo view --json url -q .url)"
echo "  (Cuando decidas hacerlo público: gh repo edit --visibility public)"
