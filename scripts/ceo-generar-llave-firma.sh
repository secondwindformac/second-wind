#!/usr/bin/env bash
# Genera la llave con la que se firman las actualizaciones de Second Wind.
#
# Qué hace, en simple (se corre UNA sola vez, en TU Mac, nunca en el servidor):
#  1. Crea dos archivos: una llave PRIVADA (la "firma", secreta) y una PÚBLICA.
#  2. Te pide una contraseña para proteger la privada. Anótala en tu gestor de contraseñas.
#  3. Guarda la privada en ~/.second-wind-firma/. Súbela también como archivo adjunto
#     a tu gestor de contraseñas (ej. 1Password): si la pierdes, no se pueden firmar más versiones.
#  4. La PÚBLICA no es secreta: el script la muestra al final; pásasela a Claude para el repo.
#  5. Nunca envíes la privada por chat, correo, Drive ni GitHub.
set -euo pipefail

DIR="$HOME/.second-wind-firma"
KEY="$DIR/second-wind-release.key"
PUB="$DIR/second-wind-release.pub"

if ! command -v minisign >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Instalando minisign (herramienta de firma, código abierto)..."
    brew install minisign
  else
    echo "Falta 'minisign'. Instala Homebrew (https://brew.sh) y vuelve a correr este script."
    exit 1
  fi
fi

if [ -e "$KEY" ]; then
  echo "Ya existe una llave en $KEY. No la reemplazo (reemplazarla dejaría a los"
  echo "clientes sin poder recibir actualizaciones). Si de verdad quieres otra, habla con Claude primero."
  exit 1
fi

mkdir -p "$DIR"; chmod 700 "$DIR"
echo "Ahora minisign te pedirá una contraseña dos veces. Elige una fuerte y guárdala en tu gestor."
minisign -G -p "$PUB" -s "$KEY"
chmod 600 "$KEY"

echo
echo "Listo. Llave privada (SECRETA): $KEY"
echo "Respáldala como adjunto en tu gestor de contraseñas junto con su contraseña."
echo
echo "Llave PÚBLICA (esta sí se puede compartir; pásasela a Claude):"
sed -n 2p "$PUB"
