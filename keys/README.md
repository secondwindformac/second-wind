# Release signing key

`second-wind-release.pub` is the PUBLIC half of the key that signs every
release payload (minisign, Ed25519). The same value is embedded in
`bin/second-wind-update` as `RELEASE_PUBKEY`; `tests/updater/test_release_signature.sh`
fails if they drift.

The PRIVATE half never lives in this repository, on GitHub, or on the build
server. It is generated and kept on the owner's own computer
(`scripts/ceo-generar-llave-firma.sh`) and used there to sign each release
(`scripts/firmar-release.sh`).

While the file holds the placeholder, installed machines refuse every update
(fail closed).
