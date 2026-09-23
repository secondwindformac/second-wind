#!/usr/bin/env bash
# Builds the Broadcom `wl` WiFi module that the USB stick installs OFFLINE on
# Broadcom Macs (BCM4360 family: MacBook Air/Pro 2013-2017).
#
# Why prebuilt (22/23-09, real Air 2013): those Macs have no internet during
# the install (their WiFi needs this very driver). The official 24.04.4 ISO
# ships broadcom-sta-dkms 23ubuntu1.1, which FAILS to build against the ISO's
# own 6.17 kernel (LP #2120508, fixed in 23ubuntu1.2). So we compile the fixed
# 23ubuntu1.3 once, against the exact kernel the ISO installs, and ship the
# result. DKMS takes over online at firstboot (module 15) for future kernels.
#
# Runs on Ubuntu 24.04 (CI: .github/workflows/wl-driver.yml) with gcc-13, the
# compiler the Ubuntu kernel was built with. Every input is pinned by sha256.
#
#   bash usb/drivers/build-wl.sh <out-dir>
set -euo pipefail
cd "$(dirname "$0")/../.."
# shellcheck disable=SC1091
source versions.lock
OUT="${1:?usage: build-wl.sh <out-dir>}"
mkdir -p "$OUT"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fetch() {  # url sha256
  local f="$WORK/$(basename "$1")"
  curl -fsSL --retry 3 -o "$f" "$1"
  echo "$2  $f" | sha256sum -c - >/dev/null
  dpkg-deb -x "$f" "$WORK/root"
}
fetch "$WL_STA_DEB_URL" "$WL_STA_DEB_SHA256"
fetch "$WL_HEADERS_DEB_URL" "$WL_HEADERS_DEB_SHA256"
fetch "$WL_HEADERS_COMMON_DEB_URL" "$WL_HEADERS_COMMON_DEB_SHA256"

KDIR="$WORK/root/usr/src/linux-headers-$WL_KERNEL"
SRC="$(echo "$WORK"/root/usr/src/broadcom-sta-*)"
make -C "$SRC" KVER="$WL_KERNEL" KBUILD_DIR="$KDIR" >"$WORK/build.log" 2>&1 \
  || { tail -40 "$WORK/build.log"; exit 1; }

ko="$SRC/wl.ko"
grep -qa "vermagic=$WL_KERNEL " "$ko" || { echo "vermagic mismatch" >&2; exit 1; }
strip --strip-debug "$ko"
name="wl-$WL_KERNEL.ko.xz"
xz -9 -c "$ko" > "$OUT/$name"
# Broadcom's license must travel with every copy of the binary (its §2.3).
sed -n '/SOFTWARE LICENSE AGREEMENT/,/^License: PD/p' \
  "$WORK/root/usr/share/doc/broadcom-sta-dkms/copyright" | sed '$d' | sed 's/^ \.\?//' \
  > "$OUT/LICENSE-broadcom-wl.txt"
cp "$WORK/root/etc/modprobe.d/broadcom-sta-dkms.conf" "$OUT/blacklist-wl-conflicts.conf"
(cd "$OUT" && sha256sum "$name")
