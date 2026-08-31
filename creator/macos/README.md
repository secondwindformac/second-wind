# Second Wind Creator (macOS)

The "create it from macOS in 3 clicks" app: a person still running macOS on
their 2013–2017 Mac uses this to prepare the Second Wind install USB — no
terminal, ever.

What it does, in order:

1. **Two mandatory promises** (the backup locks): "I saved what I care
   about" + "I understand the target Mac is fully erased". Both required,
   on purpose, plus the plug-into-power reminder.
2. **Download + verify**: the official Ubuntu ISO (untouched, pinned
   SHA-256) and the Second Wind payload from the latest GitHub release
   (`creator-manifest.json` decides versions; SHA-256 verified during
   download; resumes if interrupted).
3. **Choose the stick**: only external, physical, removable disks ≥ 8 GB are
   listed — never the Mac's own disk (triple-guarded, boot disk excluded).
4. **Type-to-confirm**, then one system password dialog (Apple's own
   `authopen` — no custom privileged helpers) and the stick is written:
   ISO bytes → GPT patched (backup moved to device end, 512 MiB `CIDATA`
   partition appended) → FAT32 seed volume built in place → read-back
   verification → eject. Byte-compatible with `scripts/make-usb.sh`.
5. **The rescue card**: boot steps (⌥ at power-on → EFI Boot) and
   secondwindformac.com/rescue.

## Layout

- `Sources/CreatorCore` — the engine: GPT patch, FAT32 volume builder,
  tar.gz reading, resumable verified downloads. **Compiles on Linux too**,
  which is how CI proves the disk structures with `sgdisk`, `fsck.vfat` and
  `mtools` (the `verify-engine-linux` job) without a Mac.
- `Sources/SecondWindCreator` — the SwiftUI app (wizard views, disk
  enumeration via `diskutil -plist`, `authopen` descriptor passing).
- `Sources/seedtool` — CLI over the engine for CI and debugging: build the
  seed FAT image or a whole "stick" image against plain files.
- `Tests/CreatorCoreTests` — structural unit tests (GPT invariants, FAT
  extents, tarball handling, password-placeholder substitution).

## Build

On a Mac (Xcode command line tools installed):

```bash
cd creator/macos && swift build
```

Package the distributable app (unsigned):

```bash
cd creator/macos && bash scripts/package-app.sh 0.9.0
```

Or just push: the `creator-macos` GitHub workflow builds the zip artifact on
every change under `creator/`.

## Deployment floor: macOS 11 Big Sur — do not raise it

A 2013–2014 Mac tops out at Big Sur. That is exactly the person this app is
for. No SwiftUI API newer than macOS 11 (`.task`, `NavigationStack`, etc.).
Built for `x86_64` (runs via Rosetta on Apple Silicon).

## Unsigned betas

There is no Apple Developer signature yet (deliberately deferred to launch
week). First launch on a beta tester's Mac: **right-click the app → Open →
Open**. That guide ships wherever the beta zip is offered.

## House rules

- The person never sees a terminal and never reads jargon ("fingerprint",
  not "checksum"; "stick", not "device node"). All copy lives in
  `L10n.swift`, English + Spanish.
- The stick layout must stay byte-compatible with `scripts/make-usb.sh` —
  they are two doors into the same tested install path.
