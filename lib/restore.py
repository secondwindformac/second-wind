#!/usr/bin/env python3
"""Manifest-driven restore (the no-sudo part).

Usage: restore.py <section>
  gsettings   → puts every key back to its original value
  dconf       → paths ending in / are wiped with reset -f; the rest are
                restored to their original value (or reset if they were unset)
  extensions  → disables and deletes ONLY the extensions we installed
  files       → deletes the files/folders we created (inside $HOME only)
                and restores the symlinks we removed
Prints every action. Never touches anything not present in the manifest.
"""
import ast
import json
import os
import shutil
import subprocess
import sys

PATH = os.path.expanduser(os.environ.get("SW_MANIFEST",
                                         "~/.local/state/second-wind/manifest.json"))
HOME = os.path.expanduser("~")


def load():
    with open(PATH) as f:
        return json.load(f)


def sh(*args, check=False):
    r = subprocess.run(args, capture_output=True, text=True)
    if check and r.returncode != 0:
        print(f"  ⚠ failed: {' '.join(args)}: {r.stderr.strip()}")
    return r.returncode == 0


def restore_gsettings(d):
    for key, v in d.get("gsettings", {}).items():
        schema, k = key.rsplit(" ", 1)
        before = v.get("before", v.get("antes", ""))
        print(f"  gsettings {schema} {k} ← {before}")
        sh("gsettings", "set", schema, k, before, check=True)


def restore_dconf(d):
    for path, v in d.get("dconf", {}).items():
        before = v.get("before", v.get("antes", ""))
        if path.endswith("/"):
            print(f"  dconf reset -f {path}")
            sh("dconf", "reset", "-f", path, check=True)
        elif before:
            print(f"  dconf {path} ← {before}")
            sh("dconf", "write", path, before, check=True)
        else:
            print(f"  dconf reset {path}")
            sh("dconf", "reset", path, check=True)


def restore_extensions(d):
    uuids = d.get("extensions_installed", [])
    if not uuids:
        return
    out = subprocess.check_output(
        ["gsettings", "get", "org.gnome.shell", "enabled-extensions"]).decode().strip()
    cur = [] if out.startswith("@as") else ast.literal_eval(out)
    remaining = [u for u in cur if u not in uuids]
    if remaining != cur:
        subprocess.check_call(
            ["gsettings", "set", "org.gnome.shell", "enabled-extensions", str(remaining)])
    for u in uuids:
        path = os.path.join(HOME, ".local/share/gnome-shell/extensions", u)
        if os.path.isdir(path):
            print(f"  extension removed: {u}")
            shutil.rmtree(path, ignore_errors=True)


def restore_files(d):
    for path in d.get("files_created", []):
        real = os.path.realpath(os.path.expanduser(path))
        if not real.startswith(HOME + os.sep):
            print(f"  ⚠ outside $HOME, left alone: {path}")
            continue
        if os.path.isdir(path) and not os.path.islink(path):
            print(f"  folder removed: {path}")
            shutil.rmtree(path, ignore_errors=True)
        elif os.path.lexists(path):
            print(f"  file removed: {path}")
            os.remove(path)
    for e in d.get("files_removed", []):
        path, target = e.get("path", e.get("ruta")), e.get("symlink")
        if target and path and not os.path.lexists(path):
            print(f"  symlink restored: {path} → {target}")
            os.makedirs(os.path.dirname(path), exist_ok=True)
            os.symlink(target, path)


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    if not os.path.exists(PATH):
        print("No manifest; nothing to restore.")
        return 0
    d = load()
    {"gsettings": restore_gsettings,
     "dconf": restore_dconf,
     "extensions": restore_extensions,
     "files": restore_files}[sys.argv[1]](d)
    return 0


if __name__ == "__main__":
    sys.exit(main())
