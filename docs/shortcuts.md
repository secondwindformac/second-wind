# Keyboard shortcuts after installing Second Wind

The **⌘ Cmd** key of your Apple keyboard works like on macOS (handled by the
Toshy service, running invisibly in the background):

| Shortcut | What it does |
|---|---|
| `Cmd + Space` | Spotlight (search apps and files) |
| `Cmd + C / V / X` | Copy / paste / cut |
| `Cmd + Z` / `Cmd + Shift + Z` | Undo / redo |
| `Cmd + A` | Select all |
| `Cmd + T` | New tab |
| `Cmd + W` | Close tab/window |
| `Cmd + Q` | Quit the application |
| `Cmd + Tab` | Switch apps (across ALL apps on all workspaces, like a Mac) |
| `Cmd + H` | Minimize/hide the window |
| `Cmd + Shift + 3` | Full-screen screenshot |
| `Cmd + Shift + 4` | Screenshot of the active window |
| `Cmd + Shift + 5` | Screenshot with options (select area, record…) |
| `Cmd + ,` | App preferences (where available) |
| In the Terminal: `Cmd + C` | Copies text (Ctrl+C still interrupts programs, like on a Mac) |

Trackpad gestures (native to Ubuntu):

| Gesture | What it does |
|---|---|
| 3 fingers up | Overview (Mission Control) |
| 3 fingers sideways | Switch workspace |
| Mouse to the top-left corner | Overview (hot corner) |

Technical detail: per-app mapping needs the Xremap extension (installed by
Second Wind) and activates after logging out. If you ever want the keyboard
engine's own control panel, run `toshy-tray` in a terminal; Second Wind hides
it by default to avoid confusion.
