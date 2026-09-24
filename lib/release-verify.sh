#!/bin/bash
# Second Wind — release signature check (minisign format, Ed25519).
#
# Why: the updater installs code as root on every customer machine. A checksum
# downloaded from the SAME GitHub release proves nothing if someone takes over
# the GitHub organisation. A signature made with a private key that lives only
# on the owner's own computer (never on GitHub, never on the build server) does.
#
# sw_verify_release FILE SIGFILE PUBKEY EXPECTED_NAME
#   FILE           the downloaded tarball
#   SIGFILE        its .minisig
#   PUBKEY         base64 minisign public key (the "RW..." line)
#   EXPECTED_NAME  e.g. second-wind-1.2.3.tar.gz — must equal the signed
#                  trusted comment "file:<name>", so an old (validly signed)
#                  release cannot be re-labelled as a newer version.
# Returns 0 only when everything checks out. Fails closed on ANY doubt.
#
# Two interchangeable verifiers, same checks:
#   minisign  (if installed; not in a default Ubuntu)
#   openssl   (OpenSSL 3.x: Ed25519 + BLAKE2b-512; ships with Ubuntu 24.04 as
#              a dependency of ca-certificates, so it is always there)
# SW_VERIFIER=openssl|minisign forces one (used by the tests). Both are full
# verifiers: forcing either never weakens the check.

sw_release_key_configured() {
  case "$1" in RW*) [ "${#1}" -eq 56 ] ;; *) return 1 ;; esac
}

sw_verify_release() {
  local file="$1" sig="$2" pub="$3" expected="$4"
  local tmp rc=1
  [ -f "$file" ] && [ -f "$sig" ] || { echo "verify: missing file or signature"; return 1; }
  sw_release_key_configured "$pub" || { echo "verify: no release key configured"; return 1; }
  tmp="$(mktemp -d)" || return 1
  _sw_verify_inner "$file" "$sig" "$pub" "$expected" "$tmp" && rc=0
  rm -rf "$tmp"
  return $rc
}

_sw_verify_inner() {
  local file="$1" sig="$2" pub="$3" expected="$4" tmp="$5"
  local line2 line3 tc verifier
  # Strict 4-line minisign layout.
  [ "$(wc -l < "$sig")" -ge 3 ] || { echo "verify: malformed signature"; return 1; }
  line2="$(sed -n 2p "$sig" | tr -d '\r')"
  line3="$(sed -n 3p "$sig" | tr -d '\r')"
  case "$line3" in "trusted comment: "*) ;; *) echo "verify: malformed signature"; return 1 ;; esac
  tc="${line3#trusted comment: }"
  [ "$tc" = "file:$expected" ] || { echo "verify: signature is for '$tc', not '$expected'"; return 1; }

  printf '%s' "$pub"   | base64 -d > "$tmp/pk"  2>/dev/null || { echo "verify: bad public key"; return 1; }
  printf '%s' "$line2" | base64 -d > "$tmp/sg"  2>/dev/null || { echo "verify: bad signature encoding"; return 1; }
  [ "$(wc -c < "$tmp/pk")" -eq 42 ] && [ "$(wc -c < "$tmp/sg")" -eq 74 ] \
    || { echo "verify: bad key or signature length"; return 1; }
  # Only the pre-hashed algorithm ("ED" = Ed25519 over BLAKE2b-512), which is
  # minisign's default since 0.10. Legacy "Ed" is refused.
  [ "$(head -c 2 "$tmp/sg")" = "ED" ] || { echo "verify: unsupported signature algorithm"; return 1; }
  [ "$(head -c 2 "$tmp/pk")" = "Ed" ] || { echo "verify: unsupported key algorithm"; return 1; }
  [ "$(head -c 10 "$tmp/sg" | tail -c 8 | od -An -tx1 | tr -d ' \n')" = \
    "$(head -c 10 "$tmp/pk" | tail -c 8 | od -An -tx1 | tr -d ' \n')" ] \
    || { echo "verify: signed with a different key"; return 1; }

  verifier="${SW_VERIFIER:-}"
  if [ -z "$verifier" ]; then
    if command -v minisign >/dev/null 2>&1; then verifier=minisign; else verifier=openssl; fi
  fi
  case "$verifier" in
    minisign)
      command -v minisign >/dev/null 2>&1 || { echo "verify: minisign not installed"; return 1; }
      minisign -V -q -P "$pub" -m "$file" -x "$sig" >/dev/null 2>&1 \
        || { echo "verify: BAD signature (minisign)"; return 1; }
      ;;
    openssl)
      command -v openssl >/dev/null 2>&1 || { echo "verify: openssl not installed"; return 1; }
      # Ed25519 public key as PEM (SPKI DER prefix for OID 1.3.101.112 + 32 bytes).
      { printf '\x30\x2a\x30\x05\x06\x03\x2b\x65\x70\x03\x21\x00'; tail -c 32 "$tmp/pk"; } > "$tmp/pk.der"
      openssl pkey -pubin -inform DER -in "$tmp/pk.der" -out "$tmp/pk.pem" 2>/dev/null \
        || { echo "verify: openssl cannot load Ed25519 key"; return 1; }
      tail -c 64 "$tmp/sg" > "$tmp/sig.bin"
      openssl dgst -blake2b512 -binary "$file" > "$tmp/hash" 2>/dev/null \
        && [ "$(wc -c < "$tmp/hash")" -eq 64 ] || { echo "verify: openssl lacks BLAKE2b-512"; return 1; }
      openssl pkeyutl -verify -pubin -inkey "$tmp/pk.pem" -rawin \
        -in "$tmp/hash" -sigfile "$tmp/sig.bin" >/dev/null 2>&1 \
        || { echo "verify: BAD signature (openssl)"; return 1; }
      # Global signature: binds the trusted comment (file name) to the signature.
      sed -n 4p "$sig" | tr -d '\r\n' | base64 -d > "$tmp/gsig" 2>/dev/null
      [ "$(wc -c < "$tmp/gsig")" -eq 64 ] || { echo "verify: malformed global signature"; return 1; }
      { cat "$tmp/sig.bin"; printf '%s' "$tc"; } > "$tmp/gmsg"
      openssl pkeyutl -verify -pubin -inkey "$tmp/pk.pem" -rawin \
        -in "$tmp/gmsg" -sigfile "$tmp/gsig" >/dev/null 2>&1 \
        || { echo "verify: BAD trusted comment signature (openssl)"; return 1; }
      ;;
    *) echo "verify: unknown verifier '$verifier'"; return 1 ;;
  esac
  echo "verify: OK ($verifier, $expected)"
  return 0
}
