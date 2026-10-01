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

echo "PASS test_factory_seed"
