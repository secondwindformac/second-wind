# Contributing to Second Wind

Thank you for wanting to help give old Macs a second wind. Bug reports and
pull requests are welcome — the code is published precisely so anyone can
read it, audit it and improve it.

## Ground rules

- **Issues**: tell us the Mac model, the Ubuntu version and what you expected
  to happen. Screenshots help. English or Spanish, both fine.
- **Pull requests**: keep them small and focused. The installer must stay
  boring: idempotent modules, everything reversible, and no surprises for
  non-technical users (they never see a terminal).
- **Never vendor third-party code.** Themes, extensions and drivers are
  downloaded from their official sources at the versions pinned in
  `versions.lock`; they are not copied into this repository. See
  [THIRD_PARTY.md](THIRD_PARTY.md).

## Contributor license grant

Second Wind is licensed under [PolyForm Shield 1.0.0](LICENSE), which
requires a single licensor for the whole work. By submitting a contribution
(a pull request, a patch, or code posted in an issue) you agree that:

1. The contribution is your own work and you have the right to grant this.
2. You grant Second Wind a perpetual, worldwide, non-exclusive,
   royalty-free, irrevocable license to use, reproduce, modify, distribute,
   sublicense and relicense your contribution as part of Second Wind or
   related products.
3. You keep the copyright to your contribution and remain free to use it
   elsewhere for any purpose.

If you'd rather not agree to this, open an issue describing the change
instead of sending code — reports and ideas need no paperwork.
