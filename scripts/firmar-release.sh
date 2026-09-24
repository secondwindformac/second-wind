#!/usr/bin/env bash
# Firma el paquete de una versión de Second Wind. Se corre en TU Mac (donde vive
# la llave privada), nunca en el servidor.
#
#   ./scripts/firmar-release.sh ~/Downloads/second-wind-1.2.3.tar.gz
#
# Crea second-wind-1.2.3.tar.gz.minisig al lado del paquete. Ese archivo .minisig
# (no es secreto) es lo que se sube junto a la versión. Te pedirá la contraseña
# de la llave.
set -euo pipefail

KEY="${SW_SIGNING_KEY:-$HOME/.second-wind-firma/second-wind-release.key}"
FILE="${1:-}"
[ -n "$FILE" ] && [ -f "$FILE" ] || { echo "Uso: $0 ruta/al/second-wind-X.Y.Z.tar.gz"; exit 1; }
NAME="$(basename "$FILE")"
[[ "$NAME" =~ ^second-wind-[0-9]+\.[0-9]+(\.[0-9]+)?\.tar\.gz$ ]] \
  || { echo "El archivo debe llamarse second-wind-X.Y.Z.tar.gz (es: $NAME)"; exit 1; }
command -v minisign >/dev/null 2>&1 || { echo "Falta minisign: corre primero scripts/ceo-generar-llave-firma.sh"; exit 1; }
[ -f "$KEY" ] || { echo "No encuentro la llave privada en $KEY"; exit 1; }

# El comentario firmado ata la firma al nombre exacto (y por lo tanto a la
# versión): una versión vieja no puede hacerse pasar por una nueva.
minisign -S -s "$KEY" -m "$FILE" -x "$FILE.minisig" -t "file:$NAME"

# Autocomprobación con la llave pública del repo (si este script corre desde el repo).
PUBFILE="$(cd "$(dirname "$0")/.." && pwd)/keys/second-wind-release.pub"
if [ -f "$PUBFILE" ] && sed -n 2p "$PUBFILE" | grep -q '^RW'; then
  minisign -V -p "$PUBFILE" -m "$FILE" -x "$FILE.minisig" >/dev/null \
    && echo "Firma comprobada con la llave pública del repo." \
    || { echo "OJO: la firma NO calza con la llave pública del repo. No subas esta versión."; exit 1; }
fi
echo "Listo: $FILE.minisig (súbelo junto al paquete o pásaselo a Claude)."
