#!/usr/bin/env bash
# Assemble Second Wind Creator.app from the SPM build output.
# Runs on macOS (CI or a developer Mac): sips/iconutil build the icon set.
#   ./scripts/package-app.sh [version]
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-0.9.0}"
ARCH="x86_64"   # our audience: Intel Macs (runs on Apple Silicon via Rosetta)

swift build -c release --arch "$ARCH"
BIN="$(swift build -c release --arch "$ARCH" --show-bin-path)/SecondWindCreator"

APP="dist/Second Wind Creator.app"
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/SecondWindCreator"
sed "s/@VERSION@/$VERSION/g" scripts/Info.plist > "$APP/Contents/Info.plist"

# Icon: .icns from the 1024 PNG.
ICONSET="dist/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 64 128 256 512; do
  sips -z "$size" "$size" assets/icon-1024.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" assets/icon-1024.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

# Unsigned on purpose for the beta phase (Apple Developer account deferred to
# launch week). Betas open it with right-click → Open.
(cd dist && zip -qry "SecondWindCreator-$VERSION-mac.zip" "Second Wind Creator.app")
echo "dist/SecondWindCreator-$VERSION-mac.zip"
