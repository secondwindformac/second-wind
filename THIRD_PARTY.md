# Third-party components

Second Wind (PolyForm Shield 1.0.0 license) does **not** bundle or redistribute these
components: the installer downloads them from their official sources, at the
exact versions pinned in `versions.lock`, and they land on the user's machine
under their own licenses.

| Component | Use | License | Source |
|---|---|---|---|
| MacTahoe GTK theme (vinceliuice) | Window and panel theme | GPL-3.0 | https://github.com/vinceliuice/MacTahoe-gtk-theme |
| MacTahoe icon theme + cursors (vinceliuice) | Icons and cursor | GPL-3.0 | https://github.com/vinceliuice/MacTahoe-icon-theme |
| Inter (rsms) | System font | SIL OFL 1.1 | https://github.com/rsms/inter |
| User Themes (GNOME) | Enables the panel theme | GPL-2.0+ | https://extensions.gnome.org/extension/19/user-themes/ |
| Blur my Shell (aunetx) | Panel blur | GPL-3.0 | https://extensions.gnome.org/extension/3193/blur-my-shell/ |
| Xremap (k0kubun) | Focused-app detection (per-app keyboard) | MIT | https://extensions.gnome.org/extension/5060/xremap/ |
| Logo Menu (aryan_k) | Mac-style top-left menu (with Second Wind's own ⌘ icon) | GPL-3.0 | https://extensions.gnome.org/extension/4451/logo-menu/ |
| facetimehd + facetimehd-firmware (patjak) | FaceTime HD camera driver | GPL-2.0 (driver) | https://github.com/patjak/facetimehd |
| mbpfan (linux-on-mac) | Fan control | GPL-3.0 | Ubuntu's `mbpfan` package |
| Toshy (RedBearAK) | Per-app Mac-style keyboard | GPL-3.0 | https://github.com/RedBearAK/toshy — Second Wind configures it when present; its installation lands in Stage 1 |
| Ulauncher | Search (Spotlight) | GPL-3.0 | https://ulauncher.io — same as above |

Notes:

- The **camera firmware** belongs to Apple; the installer extracts it locally
  from an official Apple package on the user's machine (the
  `facetimehd-firmware` tool) and it is **never** redistributed.
- The Spotlight CSS theme for Ulauncher (`assets/ulauncher/user-themes/`) is
  Second Wind's own code (PolyForm Shield 1.0.0); it inherits styles from
  Ulauncher's "light" theme by reference (`@import` of the local path),
  without copying its code.
- The ⌘ command-symbol icon (`assets/command-symbolic.svg`) is an original
  drawing (PolyForm Shield 1.0.0). The command symbol itself (U+2318) is a
  freely usable character; no Apple trademarks are included.
