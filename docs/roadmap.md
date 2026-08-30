# Roadmap

## Stage 1 — pending items, ordered by impact

1. **Install what today is only configured**: Toshy (keyboard) and Ulauncher
   (Spotlight) must install automatically when missing, version-pinned, so the
   installer works on clean machines.
2. **Coordinated light/dark mode**: MacTahoe Light and Dark are both
   installed; Ubuntu's dark-mode switch should change theme+icons+shell
   together (via `color-scheme` + a dynamic user-theme).
3. **Mac-style apps** (module 70): enable Flatpak; propose a basic pack —
   photo viewer, music, OnlyOffice (more Mac-looking than LibreOffice) — and
   **Quick Look** (press Space to preview files, via GNOME Sushi).
4. **Firefox theme**: MacTahoe's `tweaks.sh -f` adapted to the snap profile
   (`~/snap/firefox/common/.mozilla`).
5. **English docs for everything user-visible in GNOME** and more languages
   for installer strings (the i18n scaffolding is in `lib/i18n/`).
6. **Mac model detection via DMI** to enable per-model fixes (each model has
   its quirks: sensors, WiFi, camera).
7. **GNOME 47/48 support** (Ubuntu 24.10+/26.04) by re-pinning
   `versions.lock` per release, LTS-first policy.
8. **Evaluate the Kiwi + Kiwi Menu extension pair** as an upgrade over Logo
   Menu (adds "About This Computer", Recent Items, window controls in the
   panel when maximized).
9. **Installer GUI** (the whiptail TUI covers Stage 0).
10. **Business decision**: open (MIT already allows it) vs. sell packaged; own
    code is MIT and GPL components are downloaded separately, so both doors
    stay open.

## Honest feasibility notes (asked by users)

- **Global menu bar (File/Edit/View in the top bar, like macOS)**: not
  reliably possible on modern GNOME. GTK4/libadwaita apps no longer export
  traditional menu bars (the toolkit moved to hamburger menus), and the old
  global-menu extensions (Fildem, gnomehud) are X11-only and abandoned. What
  IS possible: the ⌘ system menu (done, Stage 0) and Kiwi Menu's richer
  Apple-style menu (Stage 1 evaluation). A faithful global menu would require
  per-app patching that would break constantly — we choose not to fake it.
- **Desktop widgets (weather, calendar, notes on the desktop, like macOS
  Sonoma)**: GNOME has no native desktop-widget system. Conky can draw
  widgets but behaves poorly under GNOME Wayland (it becomes a normal window
  that cannot stay glued to the desktop). Realistic paths, in order: (a) the
  calendar/weather that already live in the top-bar clock menu, (b) a curated
  Conky setup once its Wayland layer-shell support matures, (c) writing our
  own GNOME extension for desktop widgets — a real product differentiator,
  but Stage 2+ scope.

## Stage 2 — "a new Mac on a USB stick"

Vision: a non-technical user, still on macOS, creates a USB stick that
installs Ubuntu + Second Wind in one go, without ever seeing a terminal.

- **Self-installing USB**: official Ubuntu ISO + `autoinstall` seed
  (subiquity/NoCloud, `CIDATA` volume): 100% unattended install that leaves
  Second Wind applied before the first login. The ISO is never redistributed
  (no 3 GB hosting, no legal questions).
- **USB creator on macOS**: first a web guide + balenaEtcher; goal: our own
  app ("Create your new Mac in 3 clicks"). Boot holding the Option key.
- **Key decisions for that stage**: wipe macOS vs. dual-boot (irreversible —
  very strong warning UX), optional disk encryption, model detection, a real
  USB test on the reference machine.
- Stage 0 already paves the way: idempotent installer, unattended mode
  (`--yes`) and hardware-aware modules.
