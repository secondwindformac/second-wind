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

## Safety guards (council P0, 2026-08-31 — pending one full VM re-rehearsal)

- **The stick refuses non-Mac machines**: an autoinstall early-command checks
  the DMI vendor and aborts with a bilingual message before any disk is
  touched (QEMU is allowed for the VM test bench).
- **Only Apple internal disks can be selected**: the storage layout matches
  `model: APPLE*` — an external USB drive or a PC's disk can never be wiped.
  Known, accepted limit: a Mac with a third-party replacement SSD stops with
  an error instead of installing; those users take the classic `install.sh`
  path.
- **First-boot retries**: the first-login bootstrap stays armed until
  `install.sh` finishes successfully. Power cut or failure → the next login
  resumes with a friendly notice; only success disarms it.
- **GA kernel on new installs**: the HWE kernel rolls to new majors and can
  break the Broadcom `wl` WiFi driver, so installs pin to the GA 6.8 series
  (LTS-first, like everything in `versions.lock`). Offline installs quietly
  stay on HWE.

⚠ These four changes modify the certified flow: run the full VM rehearsal
again (including a mid-install power-cut simulation) before writing a
physical stick — and re-verify the camera driver builds on GA 6.8.

## Current limits (v0)

- Creator from macOS: in the works at [creator/macos](../creator/macos/) —
  engine already CI-validated against sgdisk/fsck/mtools.
- Dual-boot is not offered: the stick exists to give the whole machine a
  second wind.
