# Mac compatibility matrix

Which Intel Macs can run Second Wind today, which are next, and exactly what
each pending model needs. The installer already detects the model (DMI product
name, e.g. `MacBookAir6,2`) and the exact hardware (PCI IDs), so one Second
Wind serves every model — modules simply skip hardware that isn't there.

**Legend**
- ✅ **Validated** — full end-to-end run on real hardware (or the VM pipeline).
- 🟢 **Expected OK** — same hardware family as a validated model; untested on
  metal. Community reports welcome.
- 🟡 **In progress** — works partially; needs the per-model module below.
- ⛔ **Out of scope for v1**.

## The matrix

| Model (identifier) | Years | Keyboard / trackpad | Wi-Fi | Camera | Status |
|---|---|---|---|---|---|
| MacBook Air 11″/13″ (`MacBookAir6,x`) | 2013–2014 | USB, stock kernel | Broadcom `wl` (auto-installed) | facetimehd (BCM1570) | ✅ Validated — reference machine |
| MacBook Air 11″/13″ (`MacBookAir7,x`) | 2015–2017 | USB, stock kernel | Broadcom `wl` | facetimehd | 🟢 Expected OK |
| MacBook Pro Retina 13″/15″ (`MacBookPro11,x`, `12,1`) | 2013–2015 | USB, stock kernel | Broadcom `wl` | facetimehd | 🟢 Expected OK |
| iMac 21.5″/27″ (`iMac14,x`–`17,1`) | 2013–2015 | USB/Bluetooth | Broadcom `wl` | facetimehd | 🟢 Expected OK |
| Mac mini (`Macmini7,1`) | 2014 | n/a (external) | Broadcom `wl` | n/a | 🟢 Expected OK |
| MacBook 12″ (`MacBook8,1`–`10,1`) | 2015–2017 | **SPI** — `applespi`, in-tree since kernel 5.3 ✓ | Broadcom | none issues known | 🟢 Expected OK (input path shared with MBP 2016) |
| MacBook Pro 13″/15″ (`MacBookPro13,x`, `14,x`) | 2016–2017 | **SPI** — `applespi`, in-tree, works out of the box ✓ | See below | facetimehd | 🟡 In progress — see per-model module |
| Any Mac with the **Apple T2** chip | 2018–2020 | needs `apple-bce` (out of tree) | needs T2 firmware dance | via T2 | ⛔ v1 — revisit as v2 (t2linux.org exists) |
| **Apple Silicon** (M1+) | 2020+ | — | — | — | ⛔ Not planned (still supported by Apple; Asahi's territory) |

## What the 2016–2017 MacBook Pro needs (the 🟡 row)

Verified against the community references below:

1. **Keyboard/trackpad/suspend — already fine.** The butterfly keyboard and
   trackpad speak SPI; the `applespi` driver is upstream (kernel ≥ 5.3), so
   Ubuntu 24.04 (kernel 6.8+/6.17 HWE) handles them with no extra work.
2. **Wi-Fi firmware fix (the real work).** These models carry a Broadcom
   **BCM43602**, which uses the in-tree `brcmfmac` driver — *not* the `wl`
   DKMS we auto-install for 2013–2015 Macs (installing `wl` there actually
   breaks things; our PCI detection already keeps it away). Stock firmware has
   known defects on this chip: 5 GHz networks invisible / country-code
   regulatory failures. Fix: ship the corrected `brcmfmac43602-pcie` firmware
   blob (redistributable, linux-firmware licensing) plus a small
   `brcmfmac.conf` modprobe tune.
3. **Touch Bar** (`13,2`/`13,3`/`14,2`/`14,3`): needs the out-of-tree
   **`apple-ib-tb`** DKMS module to show the Fn/media strip. Without it the
   Touch Bar simply stays black — machine otherwise usable. `13,1`/`14,1`
   have no Touch Bar and skip this entirely.
4. **Audio**: the T1-era audio layout occasionally needs a model-specific
   ALSA/UCM profile; verify during hardware validation.

Planned as **module `16-model-quirks`** (Stage 1): DMI-gated — installs the
brcmfmac firmware fix and the `apple-ib-tb` DKMS only on `MacBookPro13,x`/`14,x`,
no-op everywhere else. Blocked only on access to a physical unit for
validation; code paths are ready to write today.

References: [Dunedan/mbp-2016-linux](https://github.com/Dunedan/mbp-2016-linux),
[macbook-pro-2017-linux-guide](https://github.com/moabdrabou/macbook-pro-2017-linux-guide).

## Why T2 Macs (2018+) wait for v2

T2 machines route the keyboard, trackpad, audio and SSD through Apple's
security chip: they need the out-of-tree `apple-bce` driver, special firmware
steps for Wi-Fi/Bluetooth, and a kernel with patches that the
[t2linux.org](https://t2linux.org) community maintains. All doable — but it
multiplies the support surface, and those Macs still run a supported macOS
today. They become interesting for us exactly when Apple drops them.

## Help us validate a model

Ran Second Wind on a 🟢 model? Open an issue titled
`Model report: <identifier>` with the output of `./verify.sh` — that's how a
row earns its ✅.
