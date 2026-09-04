#!/usr/bin/env bash
# Test for lib/toshy-driver.py (R10 blocker): a fake installer reproduces every
# prompt shape of the PINNED setup_toshy.py — y/n question, INLINE secret code,
# DEFERRED secret code (printed earlier, asked later), and the Enter-gate.
# It exits 0 only if every answer is exactly right (random codes each run).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/fake_setup.py" <<'EOF'
import random, string, sys

def code():
    return ''.join(random.choice(string.ascii_letters) for _ in range(4))

# 1) admin y/n (3-attempt loop like the real one)
for _ in range(3):
    r = input('Can user "wind" run admin commands (via sudo/doas/run0)? [y/n]: ')
    if r in ('y', 'n'):
        break
else:
    sys.exit(1)
if r != 'y':
    sys.exit(1)

# 2) updated-system y/N
r = input('Have you updated your system recently? [y/N]: ')
if r not in ('y', 'Y'):
    sys.exit(1)

# 3) INLINE secret code (the exact gate that killed R10)
c = code()
print("A shell extension is installed for GNOME Wayland support, but it is not enabled:")
print("  ['xremap@k0kubun.com']")
r = input(f"To show that you read the info just above, enter the secret code '{c}': ")
if r != c:
    print("(EE) Code does not match!")
    sys.exit(1)

# 4) DEFERRED secret code: printed first, requested later
c2 = code()
print(f'The secret code for this run is "{c2}". You will need this.')
print('Some long explanation follows here...')
r = input('If you want to proceed, enter the secret code: ')
if r != c2:
    sys.exit(1)

# 5) Enter-gate
input('  Press Enter to continue (elevated privileges expired)... ')

print('   >> Task completed successfully <<   ')
sys.exit(0)
EOF

# Happy path: the driver must answer everything correctly → exit 0.
out="$(python3 "$ROOT/lib/toshy-driver.py" python3 "$TMP/fake_setup.py" 2>&1)" \
  || { echo "FAIL: driver did not complete the fake install"; echo "$out" | tail -5; exit 1; }
echo "$out" | grep -q "Task completed successfully" \
  || { echo "FAIL: success marker missing from mirrored output"; exit 1; }

# Exit-code propagation: a failing installer must fail the driver too.
cat > "$TMP/fail.py" <<'EOF'
import sys
print("boom")
sys.exit(3)
EOF
python3 "$ROOT/lib/toshy-driver.py" python3 "$TMP/fail.py" >/dev/null 2>&1 \
  && { echo "FAIL: nonzero installer exit not propagated"; exit 1; }

echo "PASS test_toshy_driver"
