#!/usr/bin/env python3
"""Second Wind OEM license: offline Ed25519 verification (docs/modo-fabrica.md 3.6, 4.1).

A license is a short, single-line text key:

    SWOEM1:<batch>:<serial>:<base64url-no-pad signature>

The signature covers a canonical message built from the version, the batch and
the serial:

    SWOEM1
    batch=<batch>
    serial=<serial>
    kind=oem

Second Wind signs with its offline private key (scripts/oem-license.py, which
never ships in the product); the device verifies with the public key at
assets/oem-pub.pem. No server, no internet. Until the real public key is put in
place, the shipped placeholder makes every key fail verification.

This module is import-only library + a small CLI used by bin/second-wind-experience
and bin/second-wind-factory-deliver:

    oem_license.py verify-key  <pubkey> <key>
    oem_license.py verify-file <pubkey> <file>
"""
from __future__ import annotations

import base64
import os
import subprocess
import sys
import tempfile

KEY_PREFIX = "SWOEM1"
KEY_KIND = "oem"


class OEMError(Exception):
    pass


def parse_key(key: str) -> dict:
    """Parse a license key string into batch/serial/signature. Raises OEMError."""
    key = key.strip()
    parts = key.split(":")
    if len(parts) != 4 or parts[0] != KEY_PREFIX:
        raise OEMError("not a Second Wind OEM key")
    _, batch, serial, sig_b64 = parts
    if not batch or not serial:
        raise OEMError("empty batch or serial")
    try:
        sig = base64.urlsafe_b64decode(sig_b64 + "=" * (-len(sig_b64) % 4))
    except Exception as exc:  # noqa: BLE001
        raise OEMError("signature is not valid base64url") from exc
    if len(sig) != 64:
        raise OEMError("signature has the wrong length")
    return {"batch": batch, "serial": serial, "sig": sig, "sig_b64": sig_b64}


def canonical(batch: str, serial: str) -> bytes:
    """The exact bytes that are signed and verified. Keep in sync with scripts/oem-license.py."""
    return f"{KEY_PREFIX}\nbatch={batch}\nserial={serial}\nkind={KEY_KIND}\n".encode()


def _openssl_verify(pubkey_path: str, message: bytes, sig: bytes) -> bool:
    """Run `openssl pkeyutl -verify` on files in a private temp dir."""
    with tempfile.TemporaryDirectory() as d:
        m = os.path.join(d, "msg")
        s = os.path.join(d, "sig")
        with open(m, "wb") as fh:
            fh.write(message)
        with open(s, "wb") as fh:
            fh.write(sig)
        try:
            rc = subprocess.run(
                ["openssl", "pkeyutl", "-verify", "-pubin", "-inkey", pubkey_path,
                 "-rawin", "-in", m, "-sigfile", s],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            ).returncode
        except OSError:
            return False
        return rc == 0


def verify_key(key: str, pubkey_path: str) -> dict:
    """Verify a license key against a public key. Returns its fields or raises OEMError."""
    info = parse_key(key)
    if not os.path.isfile(pubkey_path):
        raise OEMError(f"public key not found: {pubkey_path}")
    if not _openssl_verify(pubkey_path, canonical(info["batch"], info["serial"]), info["sig"]):
        raise OEMError("signature does not verify")
    return {"batch": info["batch"], "serial": info["serial"]}


def verify_file(path: str, pubkey_path: str) -> dict:
    """Verify the first meaningful line of a license file. Raises OEMError."""
    try:
        with open(path, "r", encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if line and not line.startswith("#"):
                    return verify_key(line, pubkey_path)
    except OSError as exc:
        raise OEMError(f"cannot read license file: {exc}") from exc
    raise OEMError("license file has no key")


def _main(argv: list[str]) -> int:
    if len(argv) != 4 or argv[1] not in ("verify-key", "verify-file"):
        print("usage: oem_license.py verify-key|verify-file <pubkey> <key-or-file>", file=sys.stderr)
        return 2
    pub, target = argv[2], argv[3]
    try:
        if argv[1] == "verify-key":
            info = verify_key(target, pub)
        else:
            info = verify_file(target, pub)
    except OEMError as exc:
        print(f"INVALID: {exc}", file=sys.stderr)
        return 1
    print(f"OK batch={info['batch']} serial={info['serial']}")
    return 0


if __name__ == "__main__":
    sys.exit(_main(sys.argv))
