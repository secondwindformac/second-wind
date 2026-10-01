#!/usr/bin/env bash
# /etc/skel seeding (docs/modo-fabrica.md 3.7): the seed arms the firstboot for
# the buyer's brand-new account by dropping the autostart into /etc/skel, and
# nothing in the tree deletes /etc/skel (the buyer's account inherits it).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SEED="$ROOT/usb/seed/user-data"
DESK="$ROOT/usb/firstboot/second-wind-firstboot.desktop"

[ -f "$DESK" ] || { echo "FAIL: firstboot .desktop missing"; exit 1; }

# 1) The seed installs the autostart into /etc/skel (and into each home).
grep -q '/target/etc/skel/.config/autostart/second-wind-firstboot.desktop' "$SEED" \
  || { echo "FAIL: seed does not arm /etc/skel"; exit 1; }
grep -q 'for H in /target/home/\*' "$SEED" \
  || { echo "FAIL: seed no longer arms existing homes"; exit 1; }

# 2) The .desktop points at the firstboot script that ships in the payload.
grep -q '^Exec=/usr/local/share/second-wind/firstboot/second-wind-firstboot.sh' "$DESK" \
  || { echo "FAIL: .desktop Exec does not match the payload path"; exit 1; }

# 3) Nothing deletes /etc/skel (the delivery cleanup must leave it intact).
#    This test file is excluded so its own pattern does not match itself.
if grep -rq --exclude-dir=.git --exclude-dir=tests \
     'rm -rf /etc/skel\|rm -rf "$SW_ETC/skel\|rm -rf /target/etc/skel' "$ROOT" 2>/dev/null; then
  echo "FAIL: something deletes /etc/skel"; exit 1
fi

# 4) Factory seed variant (docs/modo-fabrica.md 3.1): make-usb.sh --factory
#    derives it from the SAME autoinstall, so the P0 guards and the storage
#    layout cannot drift; it drops the buyer identity screen and adds the marker.
MUSB="$ROOT/scripts/make-usb.sh"
BLOCK="$(sed -n '/# >>> factory-seed/,/# <<< factory-seed/p' "$MUSB")"
[ -n "$BLOCK" ] || { echo "FAIL: factory-seed block not found in make-usb.sh"; exit 1; }
# shellcheck disable=SC1090
eval "$BLOCK"

TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
seed_factory_transform < "$SEED" > "$TMPD/factory-user-data"

# The P0 guards + storage are byte-identical (inherited, not copy-pasted).
seg() { awk '/^  early-commands:/{f=1} /^  # Third-party drivers/{f=0} f' "$1"; }
[ "$(seg "$SEED")" = "$(seg "$TMPD/factory-user-data")" ] \
  || { echo "FAIL: factory seed changed the P0 guards or storage"; exit 1; }

# No buyer identity screen; a temporary technician user instead.
if printf '%s\n' "$(sed -n '/interactive-sections:/,/identity:/p' "$TMPD/factory-user-data")" | grep -q -- '- identity'; then
  echo "FAIL: factory seed still asks for the buyer identity"; exit 1
fi
grep -q '    - network'   "$TMPD/factory-user-data" || { echo "FAIL: factory seed dropped the network screen"; exit 1; }
grep -q '    username: technician' "$TMPD/factory-user-data" || { echo "FAIL: no technician user"; exit 1; }
grep -q 'username: wind'  "$TMPD/factory-user-data" && { echo "FAIL: buyer username still present"; exit 1; }

# The factory marker is created by a late-command.
grep -q '/target/etc/second-wind/factory' "$TMPD/factory-user-data" \
  || { echo "FAIL: factory seed does not create the factory marker"; exit 1; }

# make-usb.sh parses --factory and picks the variant without touching the default.
grep -q -- '--factory)' "$MUSB" || { echo "FAIL: make-usb.sh does not accept --factory"; exit 1; }
grep -q 'seed_factory_transform' "$MUSB" || { echo "FAIL: --factory is not wired to the transform"; exit 1; }
grep -q 'MODE="${SW_SEED_MODE:-normal}"' "$MUSB" || { echo "FAIL: the default seed mode is not normal"; exit 1; }
bash -n "$MUSB" || { echo "FAIL: make-usb.sh syntax"; exit 1; }

echo "PASS test_factory_seed"
