#!/usr/bin/env python3
"""Second Wind change manifest.

Records, for every change the installer makes, the ORIGINAL ("before") value
the FIRST time it is touched. uninstall.sh restores from this file.
Re-running the installer never overwrites an already-recorded "before".

Usage: manifest.py <command> [args...]
  init
  record-gsettings <schema> <key> <before_value>
  record-dconf <path> [before_value]    (path ending in / => uninstall does reset -f)
  file-created <path>
  file-removed <path> [symlink_target]
  ext-installed <uuid>
  apt-installed <package>
  dkms-installed <name/version>
  system-file <path>                    (system file created/modified with sudo)
  note <text> | has-note <text>
  get <section> | dump
"""
import datetime
import json
import os
import sys

PATH = os.path.expanduser(os.environ.get("SW_MANIFEST",
                                         "~/.local/state/second-wind/manifest.json"))

EMPTY = {"version": 1, "created": None,
         "gsettings": {}, "dconf": {},
         "files_created": [], "files_removed": [],
         "extensions_installed": [], "apt_packages": [],
         "dkms": [], "system": [], "notes": []}

# The project was born as "MacConLinux" with Spanish JSON keys; one machine
# (the reference MacBook) carries such a manifest. Translate it once on load.
_KEY_MAP = {"creado": "created", "archivos_creados": "files_created",
            "archivos_eliminados": "files_removed",
            "extensiones_instaladas": "extensions_installed",
            "paquetes_apt": "apt_packages", "sistema": "system",
            "notas": "notes"}
_PATH_MAP = [("/.local/state/macconlinux/", "/.local/state/second-wind/"),
             ("/.local/share/macconlinux/", "/.local/share/second-wind/"),
             ("/.local/share/macconlinux", "/.local/share/second-wind")]
_NOTE_MAP = {"chrome-parchado": "chrome-patched",
             "libadwaita-instalado": "libadwaita-installed",
             "gdm-instalado": "gdm-installed",
             "firefox-tematizado": "firefox-themed",
             "camara-pendiente": "camera-pending"}


def _fix_paths(value):
    if isinstance(value, str):
        for old, new in _PATH_MAP:
            value = value.replace(old, new)
        return value
    if isinstance(value, list):
        return [_fix_paths(v) for v in value]
    if isinstance(value, dict):
        return {k: _fix_paths(v) for k, v in value.items()}
    return value


def _migrate(d):
    changed = False
    for old, new in _KEY_MAP.items():
        if old in d:
            d[new] = d.pop(old)
            changed = True
    for section in ("files_created", "files_removed", "system"):
        fixed = _fix_paths(d.get(section, []))
        if fixed != d.get(section, []):
            d[section] = fixed
            changed = True
    for entry in d.get("files_removed", []) + d.get("system", []):
        if isinstance(entry, dict) and "ruta" in entry:
            entry["path"] = entry.pop("ruta")
            changed = True
    for sec in ("gsettings", "dconf"):
        for v in d.get(sec, {}).values():
            if "antes" in v:
                v["before"] = v.pop("antes")
                changed = True
    notes = d.get("notes", [])
    for i, n in enumerate(notes):
        if n in _NOTE_MAP:
            notes[i] = _NOTE_MAP[n]
            changed = True
    return changed


def load():
    if os.path.exists(PATH):
        with open(PATH) as f:
            d = json.load(f)
        if _migrate(d):
            save(d)
        return d
    return json.loads(json.dumps(EMPTY))


def save(d):
    os.makedirs(os.path.dirname(PATH), exist_ok=True)
    tmp = PATH + ".tmp"
    with open(tmp, "w") as f:
        json.dump(d, f, indent=2, ensure_ascii=False)
    os.replace(tmp, PATH)


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 2
    cmd, rest = args[0], args[1:]
    d = load()

    if cmd == "init":
        if d["created"] is None:
            d["created"] = datetime.datetime.now().isoformat(timespec="seconds")
        save(d)
    elif cmd == "record-gsettings":
        key = f"{rest[0]} {rest[1]}"
        if key not in d["gsettings"]:
            d["gsettings"][key] = {"before": rest[2]}
            save(d)
    elif cmd == "record-dconf":
        path = rest[0]
        if path not in d["dconf"]:
            d["dconf"][path] = {"before": rest[1] if len(rest) > 1 else ""}
            save(d)
    elif cmd == "file-created":
        if rest[0] not in d["files_created"]:
            d["files_created"].append(rest[0])
            save(d)
    elif cmd == "file-removed":
        entry = {"path": rest[0],
                 "symlink": rest[1] if len(rest) > 1 and rest[1] else None}
        if entry not in d["files_removed"]:
            d["files_removed"].append(entry)
            save(d)
    elif cmd == "ext-installed":
        if rest[0] not in d["extensions_installed"]:
            d["extensions_installed"].append(rest[0])
            save(d)
    elif cmd == "apt-installed":
        if rest[0] not in d["apt_packages"]:
            d["apt_packages"].append(rest[0])
            save(d)
    elif cmd == "dkms-installed":
        if rest[0] not in d["dkms"]:
            d["dkms"].append(rest[0])
            save(d)
    elif cmd == "system-file":
        entry = {"path": rest[0]}
        if entry not in d["system"]:
            d["system"].append(entry)
            save(d)
    elif cmd == "note":
        if rest[0] not in d["notes"]:
            d["notes"].append(rest[0])
            save(d)
    elif cmd == "has-note":
        return 0 if rest[0] in d["notes"] else 1
    elif cmd == "get":
        print(json.dumps(d.get(rest[0], {}), ensure_ascii=False))
    elif cmd == "dump":
        print(json.dumps(d, indent=2, ensure_ascii=False))
    else:
        print(f"unknown command: {cmd}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
