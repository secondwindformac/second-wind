#!/usr/bin/env python3
"""Restauración guiada por el manifiesto (parte sin sudo).

Uso: restore.py <seccion>
  gsettings   → repone cada clave a su valor original
  dconf       → rutas terminadas en / se limpian con reset -f; el resto se
                repone al valor original (o reset si no existía)
  extensiones → deshabilita y borra SOLO las extensiones que instalamos
  archivos    → borra los archivos/carpetas que creamos (solo dentro de $HOME)
                y repone los symlinks que quitamos
Imprime cada acción. Nunca toca nada que no esté en el manifiesto.
"""
import ast
import json
import os
import shutil
import subprocess
import sys

PATH = os.path.expanduser(os.environ.get("MCL_MANIFEST",
                                         "~/.local/state/macconlinux/manifest.json"))
HOME = os.path.expanduser("~")


def load():
    with open(PATH) as f:
        return json.load(f)


def sh(*args, check=False):
    r = subprocess.run(args, capture_output=True, text=True)
    if check and r.returncode != 0:
        print(f"  ⚠ falló: {' '.join(args)}: {r.stderr.strip()}")
    return r.returncode == 0


def restore_gsettings(d):
    for key, v in d.get("gsettings", {}).items():
        schema, k = key.rsplit(" ", 1)
        antes = v["antes"]
        print(f"  gsettings {schema} {k} ← {antes}")
        sh("gsettings", "set", schema, k, antes, check=True)


def restore_dconf(d):
    for path, v in d.get("dconf", {}).items():
        antes = v.get("antes", "")
        if path.endswith("/"):
            print(f"  dconf reset -f {path}")
            sh("dconf", "reset", "-f", path, check=True)
        elif antes:
            print(f"  dconf {path} ← {antes}")
            sh("dconf", "write", path, antes, check=True)
        else:
            print(f"  dconf reset {path}")
            sh("dconf", "reset", path, check=True)


def restore_extensiones(d):
    uuids = d.get("extensiones_instaladas", [])
    if not uuids:
        return
    out = subprocess.check_output(
        ["gsettings", "get", "org.gnome.shell", "enabled-extensions"]).decode().strip()
    cur = [] if out.startswith("@as") else ast.literal_eval(out)
    nuevos = [u for u in cur if u not in uuids]
    if nuevos != cur:
        subprocess.check_call(
            ["gsettings", "set", "org.gnome.shell", "enabled-extensions", str(nuevos)])
    for u in uuids:
        ruta = os.path.join(HOME, ".local/share/gnome-shell/extensions", u)
        if os.path.isdir(ruta):
            print(f"  extensión eliminada: {u}")
            shutil.rmtree(ruta, ignore_errors=True)


def restore_archivos(d):
    for ruta in d.get("archivos_creados", []):
        real = os.path.realpath(os.path.expanduser(ruta))
        if not (real.startswith(HOME + os.sep)):
            print(f"  ⚠ fuera de $HOME, no se toca: {ruta}")
            continue
        if os.path.isdir(ruta) and not os.path.islink(ruta):
            print(f"  carpeta eliminada: {ruta}")
            shutil.rmtree(ruta, ignore_errors=True)
        elif os.path.lexists(ruta):
            print(f"  archivo eliminado: {ruta}")
            os.remove(ruta)
    for e in d.get("archivos_eliminados", []):
        ruta, target = e["ruta"], e.get("symlink")
        if target and not os.path.lexists(ruta):
            print(f"  symlink repuesto: {ruta} → {target}")
            os.makedirs(os.path.dirname(ruta), exist_ok=True)
            os.symlink(target, ruta)


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    if not os.path.exists(PATH):
        print("No hay manifiesto; nada que restaurar.")
        return 0
    d = load()
    seccion = sys.argv[1]
    {"gsettings": restore_gsettings,
     "dconf": restore_dconf,
     "extensiones": restore_extensiones,
     "archivos": restore_archivos}[seccion](d)
    return 0


if __name__ == "__main__":
    sys.exit(main())
