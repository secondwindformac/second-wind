#!/usr/bin/env bash
# Build the Second Wind USB Creator as a Debian package (.deb) for Ubuntu.
# The user downloads it from the website and installs it with a double click —
# no terminal. Runs in CI (ubuntu-24.04) or a dev checkout.
#   packaging/build-deb.sh [version]
set -Eeuo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-$(cat VERSION 2>/dev/null | tr -d '[:space:]')}"
PKG="second-wind-usb-creator"
ARCH="amd64"                          # the old Intel Macs Second Wind revives
DEST="/opt/second-wind-creator"       # where the app lives once installed
ROOT="build/deb/${PKG}_${VERSION}_${ARCH}"

rm -rf build/deb
mkdir -p "$ROOT/DEBIAN" "$ROOT$DEST" "$ROOT/usr/share/applications"

# Runtime files (usb-creator.py derives SW_ROOT as the parent of apps/, and
# make-usb.sh cd's to its ../ — both resolve to $DEST once installed).
cp -r apps scripts lib usb versions.lock "$ROOT$DEST/"
rm -rf "$ROOT$DEST/apps/__pycache__"

# Prebuilt payload so the app never needs git at runtime (see make-usb.sh build()).
mkdir -p "$ROOT$DEST/payload"
git archive --prefix=second-wind/ HEAD | gzip > "$ROOT$DEST/payload/second-wind.tar.gz"

# App icon.
install -Dm644 creator/macos/assets/icon-1024.png "$ROOT$DEST/icon.png"

# Desktop launcher (icon in the apps grid, no terminal).
cat > "$ROOT/usr/share/applications/second-wind-usb-creator.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Second Wind USB Creator
Comment=Create a bootable Second Wind USB installer
Exec=python3 $DEST/apps/usb-creator.py
Icon=$DEST/icon.png
Terminal=false
Categories=System;Utility;
StartupNotify=true
EOF

# AppStream metadata: gives the App Center a real name, publisher, license and
# icon instead of "Unknown publisher / unknown license".
mkdir -p "$ROOT/usr/share/metainfo"
cat > "$ROOT/usr/share/metainfo/app.secondwind.USBCreator.metainfo.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>app.secondwind.USBCreator</id>
  <name>Second Wind USB Creator</name>
  <summary>Create a bootable Second Wind USB installer</summary>
  <developer_name>Second Wind</developer_name>
  <metadata_license>CC0-1.0</metadata_license>
  <project_license>LicenseRef-PolyForm-Shield-1.0.0</project_license>
  <description>
    <p>Creates a bootable Second Wind USB installer from the official, checksum-verified Ubuntu ISO. Download, double-click to install, then open it from your apps.</p>
  </description>
  <launchable type="desktop-id">second-wind-usb-creator.desktop</launchable>
  <icon type="local">$DEST/icon.png</icon>
  <url type="homepage">https://secondwindformac.com/</url>
  <content_rating type="oars-1.1"/>
</component>
EOF

# Package metadata + dependencies (apt pulls them on install).
cat > "$ROOT/DEBIAN/control" <<EOF
Package: $PKG
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Depends: python3, python3-gi, gir1.2-gtk-4.0, gir1.2-adw-1, gdisk, dosfstools, parted, util-linux, coreutils, curl, openssl, policykit-1, libnotify-bin, zenity
Maintainer: Second Wind <hello@secondwindformac.com>
Description: Second Wind USB Creator
 Creates a bootable Second Wind USB installer from the official, checksum-
 verified Ubuntu ISO. Download, double-click to install, open from your apps.
EOF

cat > "$ROOT/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
EOF
chmod 755 "$ROOT/DEBIAN/postinst"

dpkg-deb --build --root-owner-group "$ROOT" "build/deb/${PKG}_${VERSION}_${ARCH}.deb"
echo "build/deb/${PKG}_${VERSION}_${ARCH}.deb"
