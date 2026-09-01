#!/usr/bin/env bash
# Build the Second Wind USB Creator as a SINGLE-FILE AppImage — the Mac-like
# model: download one file, double-click to run, delete the file to uninstall.
# Runs in CI (ubuntu-24.04) via appimage-builder. Args: [version]
set -Eeuo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:-$(cat VERSION 2>/dev/null | tr -d '[:space:]')}"
export VERSION
DEST=/opt/second-wind-creator
APPDIR="$PWD/build/appimage/AppDir"

rm -rf build/appimage
mkdir -p "$APPDIR$DEST"

# Runtime files + prebuilt payload (no git needed at runtime).
cp -r apps scripts lib usb versions.lock "$APPDIR$DEST/"
rm -rf "$APPDIR$DEST/apps/__pycache__"
mkdir -p "$APPDIR$DEST/payload"
git archive --prefix=second-wind/ HEAD | gzip > "$APPDIR$DEST/payload/second-wind.tar.gz"

# Icon (both a hicolor path for the desktop DB and a copy the app can reference).
install -Dm644 creator/macos/assets/icon-1024.png \
  "$APPDIR/usr/share/icons/hicolor/256x256/apps/second-wind-usb-creator.png"
install -Dm644 creator/macos/assets/icon-1024.png "$APPDIR$DEST/icon.png"

# Desktop entry (appimage-builder needs one under usr/share/applications).
mkdir -p "$APPDIR/usr/share/applications"
cat > "$APPDIR/usr/share/applications/second-wind-usb-creator.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Second Wind USB Creator
Comment=Create a bootable Second Wind USB installer
Exec=AppRun
Icon=second-wind-usb-creator
Terminal=false
Categories=System;Utility;
EOF

# Build the AppImage. --skip-test avoids appimage-builder's Docker-based test;
# our CI runs its own headless --self-check on the produced AppImage instead.
appimage-builder --recipe packaging/appimage/AppImageBuilder.yml --skip-test
