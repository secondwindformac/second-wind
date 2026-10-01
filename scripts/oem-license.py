#!/usr/bin/env python3
"""Second Wind OEM license issuer (docs/modo-fabrica.md 3.6, 4.1).

THIS TOOL RUNS ON SECOND WIND'S OWN SERVER, NEVER ON A CUSTOMER MACHINE. It
holds the Ed25519 private key that signs licenses by batch.

    oem-license.py keygen --priv RUTA [--pub RUTA]
    oem-license.py issue --lote NOMBRE --cantidad N --priv RUTA [--out ARCHIVO] [--start N]

The private key MUST live outside this repository. A hardened way to keep it is
a file only readable by the signing account, for example:

    oem-license.py keygen --priv ~/.second-wind/oem-priv.pem

`keygen` also writes the matching public key, which is the only half that ships
in the product (copy it to assets/oem-pub.pem). `issue` prints one short license
key per line:

    SWOEM1:<lote>:<numero>:<firma>

Each key carries its batch, its serial number and its signature. Verification is
offline (lib/oem_license.py, openssl); no server is contacted.
"""
from __future__ import annotations

import argparse
import base64
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
import oem_license  # noqa: E402


def _openssl(args: list[str]) -> None:
    try:
        subprocess.run(["openssl", *args], check=True)
    except FileNotFoundError:
        sys.exit("openssl is required (Ubuntu 24.04 ships OpenSSL 3).")
    except subprocess.CalledProcessError as exc:
        sys.exit(f"openssl failed: {' '.join(args)} ({exc.returncode})")


def _sign(priv_path: str, message: bytes) -> bytes:
    if not os.path.isfile(priv_path):
        sys.exit(f"private key not found: {priv_path}")
    with tempfile.TemporaryDirectory() as d:
        m = os.path.join(d, "msg")
        s = os.path.join(d, "sig")
        with open(m, "wb") as fh:
            fh.write(message)
        _openssl(["pkeyutl", "-sign", "-inkey", priv_path, "-rawin", "-in", m, "-out", s])
        with open(s, "rb") as fh:
            return fh.read()


def cmd_keygen(args: argparse.Namespace) -> int:
    priv = os.path.expanduser(args.priv)
    pub = os.path.expanduser(args.pub) if args.pub else priv + ".pub"
    if os.path.exists(priv):
        sys.exit(f"refusing to overwrite an existing private key: {priv}")
    os.makedirs(os.path.dirname(os.path.abspath(priv)), exist_ok=True)
    _openssl(["genpkey", "-algorithm", "ED25519", "-out", priv])
    os.chmod(priv, 0o600)
    _openssl(["pkey", "-in", priv, "-pubout", "-out", pub])
    print(f"private key: {priv} (mode 0600, keep it OUT of the repository)", file=sys.stderr)
    print(f"public key:  {pub} (copy this to assets/oem-pub.pem)", file=sys.stderr)
    return 0


def cmd_issue(args: argparse.Namespace) -> int:
    priv = os.path.expanduser(args.priv)
    if ":" in args.lote or not args.lote:
        sys.exit("--lote cannot be empty or contain ':'")
    if args.cantidad < 1:
        sys.exit("--cantidad must be at least 1")
    lines = []
    for i in range(args.start, args.start + args.cantidad):
        serial = f"{i:04d}"
        sig = _sign(priv, oem_license.canonical(args.lote, serial))
        sig_b64 = base64.urlsafe_b64encode(sig).rstrip(b"=").decode()
        lines.append(f"{oem_license.KEY_PREFIX}:{args.lote}:{serial}:{sig_b64}")
    text = "\n".join(lines) + "\n"
    if args.out:
        with open(os.path.expanduser(args.out), "w", encoding="utf-8") as fh:
            fh.write(text)
        print(f"wrote {len(lines)} keys to {args.out}", file=sys.stderr)
    else:
        sys.stdout.write(text)
    print(f"issued {len(lines)} OEM keys for batch '{args.lote}'", file=sys.stderr)
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description="Second Wind OEM license issuer")
    sub = p.add_subparsers(dest="cmd", required=True)

    k = sub.add_parser("keygen", help="create an Ed25519 key pair")
    k.add_argument("--priv", required=True, help="path for the private key (NEVER in the repo)")
    k.add_argument("--pub", default=None, help="path for the public key (default: <priv>.pub)")
    k.set_defaults(func=cmd_keygen)

    i = sub.add_parser("issue", help="issue a batch of license keys")
    i.add_argument("--lote", required=True, help="batch name, e.g. REUSE-2026-11")
    i.add_argument("--cantidad", type=int, required=True, help="how many keys to issue")
    i.add_argument("--priv", required=True, help="path to the private key")
    i.add_argument("--out", default=None, help="write the keys to this file (default: stdout)")
    i.add_argument("--start", type=int, default=1, help="first serial number (default: 1)")
    i.set_defaults(func=cmd_issue)

    args = p.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
