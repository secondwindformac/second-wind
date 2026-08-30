# Going back to Ubuntu exactly as it was

```bash
cd second-wind
./uninstall.sh
```

What it does: using the **change manifest** (every setting recorded its
original value the first time it was touched), it restores each desktop
setting one by one, removes the extensions and files Second Wind created,
and — if you installed the hardware module — also reverts the camera driver,
mbpfan, the login screen and the rest (it will ask for your administrator
password).

Then log out and back in.

Extra options:

| Command | What it adds |
|---|---|
| `./uninstall.sh --purge-themes` | Also deletes the MacTahoe themes/icons from disk (frees ~400 MB) |
| `./uninstall.sh --full-dconf` | Last resort: restores ALL desktop settings exactly as they were on backup day (overwrites anything you changed afterwards) |

Notes:

- Your personal files are never touched.
- Toshy (the keyboard service) is not uninstalled because Second Wind did not
  install it on this machine; only its tray icon is restored. To remove it:
  `~/Toshy/setup_toshy.py remove` (or see its documentation).
- The original backup stays in `~/.local/state/second-wind/backup/pristine/`
  in case you need it.
