# Second Wind

**A second wind for your old Mac — turn Ubuntu into a macOS-like experience in one step, no Linux knowledge required.**

*Leer en español: [README.es.md](README.es.md)*

Apple left millions of perfectly capable Intel Macs without updates. With Ubuntu they are still excellent computers — but they feel foreign. Second Wind makes them feel like home:

- 🖥️ **Full macOS-style look**: window theme, icons, cursor, fonts and a dynamic day/night wallpaper (based on the macOS Tahoe look).
- 🚀 **Floating dock** and Mac-style top bar, window buttons on the left, ⌘ menu on the top-left.
- 🔍 **Spotlight**: press `Cmd + Space` and search apps and files.
- ⌨️ **A real Mac keyboard**: `Cmd+C` copies, `Cmd+V` pastes, `Cmd+Q` quits, `Cmd+Tab` switches between apps across all workspaces — and in the Terminal `Cmd+C` copies without killing the program, just like macOS.
- 🔧 **MacBook hardware fixes**: FaceTime HD camera, smart fan control and persistent F-keys.
- ↩️ **Everything reversible**: a full backup is taken before touching anything; `./uninstall.sh` puts Ubuntu back the way it was.

The installer speaks **English and Spanish** (it follows your system language).

## Requirements

- Ubuntu **24.04 LTS** with the GNOME 46 desktop (the standard install), Wayland session (the default).
- Internet connection and 2 GB of free space.
- Designed and tested on Intel MacBooks (reference machine: MacBook Air 13" 2014). It also works on regular PCs running Ubuntu 24.04 (the Mac hardware module simply skips itself).

### Why exactly Ubuntu 24.04 + GNOME 46?

Every external piece (theme, four GNOME extensions, camera driver) is **pinned to versions tested together** on the reference machine (`versions.lock`). A different GNOME release needs different pins — supporting a version means re-testing the whole experience, not hoping for the best. The plan: track Ubuntu **LTS** releases (24.04 now, 26.04 next), because owners of older Macs want stability, and let Stage 2's install USB ship the exact tested base system so end users never have to think about versions at all.

## Install

```bash
git clone https://github.com/USER/second-wind.git
cd second-wind
./install.sh
```

The installer explains what it will do, asks for **a single confirmation**, saves the backup and applies everything. At the end it asks you to log out and back in (needed for the panel theme and the per-app keyboard). The administrator password is only requested for the hardware fixes and the login screen.

Useful options:

| Command | What it does |
|---|---|
| `./install.sh --dry-run` | Show what would be done, change nothing |
| `./install.sh --yes` | Install with no questions (defaults) |
| `./install.sh --no-hardware` | Skip the steps that ask for the admin password |
| `./install.sh --only dock` | Re-run a single module |
| `./verify.sh` | Check that everything is in order |
| `./uninstall.sh` | Restore Ubuntu as it was |

## FAQ

**Does this touch my files?** No. It only configures the desktop's look and behavior. Your documents, photos and programs are untouched.

**Can I go back?** Always: `./uninstall.sh` restores every setting to its original value using the backup taken before anything changed.

**Some apps lack the red/yellow/green buttons.** Apps that draw their own window frame (Chrome, and Electron-based apps) don't use the system's buttons. For Chrome, Second Wind enables its "system title bar" option and it gets Mac buttons; for Electron apps it depends on each app and cannot be forced.

**The system menus aren't identical to macOS.** The panel and its menus belong to GNOME: Second Wind dresses them (colors, shapes, typography, a readable opaque variant), but their internal structure is Ubuntu's.

**Ubuntu's App Center looks different.** That store doesn't use the system theme technology (GTK) and cannot be dressed.

**Firefox or other Snap apps don't pick up the theme.** Known Ubuntu Snap limitation; addressed in Stage 1.

**What about battery?** Second Wind uses Ubuntu's own power management (power profiles + `thermald`), adds `mbpfan` so the fan actually responds on MacBooks, and enables the automatic power saver on low battery. TLP was deliberately left out: it fights GNOME's power profile selector. Most battery drain comes from the apps you run, not the system.

## Project status

**Stage 0** (this): one-click installer for Ubuntu 24.04/GNOME 46, tested on the reference machine.
**Stage 1**: Mac-style apps + Quick Look, coordinated dark mode, Firefox theme, auto-install of the keyboard/search engines on clean machines, more Mac models.
**Stage 2**: the total install USB — from a Mac running macOS to a "new Mac" running Ubuntu + Second Wind, without ever seeing a terminal.

See [docs/roadmap.md](docs/roadmap.md) for the honest feasibility notes (global menu bar, desktop widgets, and friends).

## License

Own code under the [MIT](LICENSE) license. Third-party components (themes, extensions, drivers) are **not redistributed**: the installer downloads them from their official sources at verified versions; see [THIRD_PARTY.md](THIRD_PARTY.md).

Second Wind is not affiliated with Apple Inc. "Mac" and "macOS" are trademarks of Apple Inc., mentioned only to describe compatibility and visual resemblance.
