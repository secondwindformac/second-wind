#!/usr/bin/env bash
# Assemble Second Wind Creator.app from the SPM build output.
# Runs on macOS (CI or a developer Mac): sips/iconutil build the icon set.
#   ./scripts/package-app.sh [version]
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-0.9.0}"
# Universal binary: runs natively on BOTH Apple Silicon and Intel Macs, so modern
# Macs never see the Rosetta prompt. The minimum deploy target still covers the old
# Intel Macs this revives.
ARCH_FLAGS=(--arch arm64 --arch x86_64)

swift build -c release "${ARCH_FLAGS[@]}"
BIN="$(swift build -c release "${ARCH_FLAGS[@]}" --show-bin-path)/SecondWindCreator"

APP="dist/Second Wind Creator.app"
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/SecondWindCreator"
sed "s/@VERSION@/$VERSION/g" scripts/Info.plist > "$APP/Contents/Info.plist"

# Swift back-deployment libraries: the deploy floor is macOS 11, but Swift
# Concurrency only ships with the OS from macOS 12. The binary links it as
# @rpath/libswift_Concurrency.dylib with rpath @executable_path/../lib, and
# dyld's /usr/lib/swift fallback only helps on 12+ — on Big Sur (the OS our
# 2013–2014 audience actually runs) there is no copy anywhere, so the app is
# killed at launch. Bundle the toolchain's back-deploy copies at Contents/lib,
# the rpath the binary already carries. Xcode does this same copy for .apps.
LIBDIR="$APP/Contents/lib"
BACKDEPLOY="$(dirname "$(xcrun --find swiftc)")/../lib/swift-5.5/macosx"
mkdir -p "$LIBDIR"
otool -L "$APP/Contents/MacOS/SecondWindCreator" \
  | awk '/@rpath\/libswift/ {print $1}' | sed 's|@rpath/||' \
  | while read -r lib; do
      cp "$BACKDEPLOY/$lib" "$LIBDIR/$lib"
    done

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
