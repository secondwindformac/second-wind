# The USB installer — "a new Mac on a USB stick" (Stage 2, v0)

One USB stick that reinstalls the whole computer: boots the **official Ubuntu
Desktop 24.04 ISO** (untouched, checksum-verified) and answers the technical
questions by itself via an **autoinstall seed** on a small `CIDATA` volume.
The person only answers the friendly screens — language, keyboard, WiFi,
name/password — then the installer **wipes the disk** and does everything.
At first login, Second Wind opens by itself and finishes the Mac experience
(one confirmation + the user's password).

## Creating the stick (from any Ubuntu machine with this repo)

```bash
./scripts/make-usb.sh                # downloads/verifies the ISO, builds the seed
lsblk -d                             # find your stick, e.g. /dev/sdb
./scripts/make-usb.sh --write /dev/sdb   # ⚠ DESTROYS everything on the stick
```

## Using it on a Mac

1. Plug it in and power on **holding Option (⌥/Alt)**; pick the orange
   **EFI Boot** entry.
2. Choose **Try or Install Ubuntu**, answer the 4 personal screens, and let
   it work (~20-30 min). ⚠ The target disk is erased completely.
3. On first login, follow the Second Wind window. If the Mac's WiFi needs
   its driver (Broadcom models), share your phone's internet **over USB
   cable** for a few minutes — Second Wind installs the WiFi driver and then
   the cable is no longer needed.

## How it works (for developers)

- The seed follows Subiquity's documented lookup: a `CIDATA` volume
  (cloud-init NoCloud `user-data`/`meta-data`) and the Desktop installer's
  `autoinstall/user-data` folder — both carry the same file, so either
  mechanism wins. The official ISO is never remastered.
- `interactive-sections` keeps locale/keyboard/network/identity human;
  storage uses the standard `direct` (wipe) layout; `drivers: install: true`
  pulls third-party drivers (Broadcom WiFi) from the ISO pool.
- A `late-command` copies the Second Wind payload (`git archive` of the repo)
  into `/usr/local/share/second-wind` and arms a one-shot autostart for every
  created user; on first login it waits for connectivity and opens the normal
  bilingual installer.
- **Validated end-to-end in a QEMU/OVMF (EFI) virtual machine** (2026-08-30):
  official ISO boot → seed consumed (account screen pre-filled, 8 of 12 wizard
  pages skipped, automatic disk wipe) → 13/13 modules → relogin → ⌘ menu, dark
  bar, MacTahoe dock, Mac login screen; verify: 31 passed, 5 "failures" all
  being hardware the VM does not have. The rehearsal caught and fixed four
  real product bugs before any human hit them: missing curl/git on stock
  installs, Toshy's interactive prompts (now tty-attached), pointless camera
  build on non-Mac machines, and the dock defaulting to the left.
- Rebuild the seed any time — the ISO stays cached. Never yank the USB before
  the "remove medium and press ENTER" prompt (the live system still needs it).

## Current limits (v0)

- Creator runs on Linux; the "make it from macOS in 3 clicks" app is the next
  step of Stage 2.
- Dual-boot is not offered: the stick exists to give the whole machine a
  second wind.
