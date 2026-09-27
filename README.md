# Second Wind

**A second wind for your old Mac.** Second Wind turns a 2013-2017 Intel Mac that Apple stopped updating into a fast, safe computer that still looks and feels like a Mac. You make a USB stick with our app, start the Mac from it, answer four questions, and it does the rest. No terminal, no Linux knowledge.

🌐 **[secondwindformac.com](https://secondwindformac.com/)**: download, demo videos, "Will my Mac work?" and FAQ.

![The same Mac after Second Wind](https://secondwindformac.com/assets/after.png)

*Leer en español: [README.es.md](README.es.md)*

## In short

- **What it is:** Ubuntu 24.04 LTS (a free, legal operating system with security updates until 2029), set up and dressed to look and behave like a Mac, with the drivers old MacBooks need.
- **Who it is for:** people with an Intel Mac from 2013-2017 that no longer gets macOS updates and who want to use it again for the internet, video calls, school, office work, music and video.
- **Price:** Second Wind is **free forever**: the full Mac look, the drivers, the app store and the updates. **Mac Experience** is only the ⌘ keyboard shortcuts and the ⌘Space search: 30 days free, then **US$10 once** (not a subscription). Without Mac Experience your Mac still looks like a Mac; only the ⌘ shortcuts go back to Linux's.
- **What it is not:** it is not macOS and contains no Apple software, logos or fonts. It uses a free community theme, the ⌘ symbol and the free Inter font. No iMessage, FaceTime, AirDrop or Mac-only apps (.dmg). If you need real macOS, see "How it compares" below.

## What you get

- **The Mac look:** dock at the bottom, top bar with a ⌘ menu, clock and status icons on the right, light Control Center, red/yellow/green window buttons, dynamic wallpaper.
- **The Mac keyboard (Mac Experience):** ⌘C, ⌘V, ⌘Z, ⌘Q, ⌘Tab, ⌘Space search, ⌘⇧3/4/5 for screenshots and screen recording.
- **Hardware that just works:** Wi-Fi (Broadcom, working from the very first start, even without internet during the install), FaceTime HD camera, sound, fan control, sleep and hibernation, function keys.
- **An app store with 22 apps:** Chrome, WhatsApp, Zoom, Spotify, office apps and more, one click each, always from official sources.
- **"Your Mac":** checks your hardware and gives you a "Copy report for support" button (a closed list of facts, shown in full before you copy it; nothing is sent).
- **Automatic updates** with automatic rollback if something gets worse.

## Will my Mac work?

| Mac | Years | Status |
|---|---|---|
| MacBook Air 11" / 13" | 2013-2017 | Ready (tested end to end on a MacBook Air A1466) |
| MacBook Pro Retina 13" / 15" | 2013-2015 | Ready (beta: tell us how it goes) |
| iMac 21.5" / 27" | 2013-2015 | Ready (beta: tell us how it goes) |
| MacBook Pro 13" / 15" (Touch Bar era) | 2016-2017 | In development |
| Macs with the Apple T2 chip | 2018+ | Not yet (the installer stops before erasing anything) |
| Apple Silicon (M1 and later) | 2020+ | No plans (Apple still supports them) |

Exact list by model number (the "A1466" under the Mac): [secondwindformac.com/compatibility](https://secondwindformac.com/compatibility/).

## How to install

1. **Make the USB stick** (8 GB or more) with **Second Wind Creator** on any Mac (or the Ubuntu app on a Linux PC). It downloads the official Ubuntu image and Second Wind and checks every piece against its official fingerprint.
2. **Start the old Mac from the stick:** hold the **Option (⌥)** key while it turns on and pick the yellow "EFI Boot" disk.
3. **Answer four questions** (language, keyboard, Wi-Fi, your name). The first time you log in, Second Wind finishes setting everything up by itself (about 15 minutes, with a progress bar).

Important: **Second Wind replaces macOS completely and erases the Mac.** Back up your files first. You can always go back to macOS with the Mac's built-in Internet Recovery: [rescue guide](https://secondwindformac.com/rescue/).

## How it compares

| If you want... | Best option |
|---|---|
| A fast, safe Mac-like computer for everyday use, with no terminal | **Second Wind** |
| Real macOS on an unsupported Mac, with Apple apps and iMessage | **OpenCore Legacy Patcher** (free; technical; macOS 26 is Apple's last version for Intel Macs, so its future is uncertain) |
| A browser-only computer (Google account, web apps) | **ChromeOS Flex** (free; some Macs are on Google's certified list) |
| A general-purpose Linux with a customizable look | **Zorin OS** or plain **Ubuntu** (Mac hardware drivers and Mac shortcuts are up to you) |

More detail: [secondwindformac.com/compare](https://secondwindformac.com/compare/).

## Privacy

Second Wind sends none of your data. It only checks for improvements, fetches the store's app icons and activates your license when you ask. No accounts, no ads.

## Help

Write to **hello@secondwindformac.com**. In "Your Mac", the "Copy report for support" button gives us what we need to help you fast.

## License

All the code is in plain sight and auditable, and free forever for your Mac. You may read, audit, change and use it, at home or at work. The one thing the license forbids is taking this code to offer a competing product. It is **source-available under [PolyForm Shield 1.0.0](LICENSE)**, not an OSI "open source" license (see [NOTICE](NOTICE)).

> Required Notice: Copyright Second Wind (https://secondwindformac.com)

Third-party components (theme, extensions, drivers) are not redistributed: the installer downloads them from their official sources at verified versions, under their own licenses; see [THIRD_PARTY.md](THIRD_PARTY.md). Contributions are welcome under [CONTRIBUTING.md](CONTRIBUTING.md).

Second Wind is an independent project, not affiliated with, endorsed or sponsored by Apple Inc. or Canonical Ltd. "Mac", "macOS" and "MacBook" are trademarks of Apple Inc., mentioned only to describe compatibility. "Ubuntu" is a trademark of Canonical Ltd.

---

## For developers

People never need this section: the USB stick does everything. It is here for anyone who wants to read, audit or improve the code.

- **Base:** Ubuntu 24.04 LTS, GNOME 46, Wayland. Every external piece is pinned to versions tested together (`versions.lock`).
- **USB installer:** official Ubuntu ISO + autoinstall seed + Second Wind payload; see [docs/usb-installer.md](docs/usb-installer.md). Creator apps: [creator/macos](creator/macos/) and `apps/usb-creator.py`.
- **Applying the layer on an existing Ubuntu 24.04 install:**

```bash
git clone https://github.com/secondwindformac/second-wind.git
cd second-wind
./install.sh            # --dry-run, --yes, --no-hardware, --only <module>
./verify.sh             # health check
./uninstall.sh          # restore Ubuntu as it was, from the backup taken first
```

- Modules live in `modules/`, the updater in `bin/second-wind-update`, the app in `apps/second-wind-apps.py`. Roadmap and honest feasibility notes: [docs/roadmap.md](docs/roadmap.md).
