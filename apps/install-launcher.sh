#!/usr/bin/env bash
# Install a desktop launcher (app icon) for the Second Wind USB Creator, so it
# opens from the applications grid with NO terminal — the way a non-technical
# user should start it. Run once:  bash apps/install-launcher.sh
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APPS="$HOME/.local/share/applications"
DESKTOP="$APPS/second-wind-usb-creator.desktop"
mkdir -p "$APPS"

cat > "$DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=Second Wind USB Creator
Comment=Create a bootable Second Wind USB installer
Exec=python3 $ROOT/apps/usb-creator.py
Icon=$ROOT/creator/macos/assets/icon-1024.png
Terminal=false
Categories=System;Utility;
StartupNotify=true
EOF

chmod +x "$DESKTOP" 2>/dev/null || true
update-desktop-database "$APPS" 2>/dev/null || true

echo "Launcher installed: $DESKTOP"
echo "Now open 'Second Wind USB Creator' from your apps — no terminal needed."
