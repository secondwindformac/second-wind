#!/usr/bin/env python3
"""Manifiesto de cambios de MacConLinux.

Registra, para cada cambio que hace el instalador, el valor ORIGINAL ("antes")
la PRIMERA vez que se toca. uninstall.sh restaura a partir de este archivo.
Re-ejecutar el instalador nunca sobreescribe un "antes" ya registrado.

Uso: manifest.py <orden> [args...]
  init
  record-gsettings <schema> <clave> <valor_antes>
  record-dconf <ruta> [valor_antes]     (ruta terminada en / => uninstall hace reset -f)
  file-created <ruta>
  file-removed <ruta> [destino_symlink]
  ext-installed <uuid>
  apt-installed <paquete>
  dkms-installed <nombre/version>
  system-file <ruta>                    (archivo del sistema creado/modificado con sudo)
  note <texto> | has-note <texto>
  get <seccion> | dump
"""
import datetime
import json
import os
import sys

PATH = os.path.expanduser(os.environ.get("MCL_MANIFEST",
                                         "~/.local/state/macconlinux/manifest.json"))

EMPTY = {"version": 1, "creado": None,
         "gsettings": {}, "dconf": {},
         "archivos_creados": [], "archivos_eliminados": [],
         "extensiones_instaladas": [], "paquetes_apt": [],
         "dkms": [], "sistema": [], "notas": []}


def load():
    if os.path.exists(PATH):
        with open(PATH) as f:
            return json.load(f)
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
        if d["creado"] is None:
            d["creado"] = datetime.datetime.now().isoformat(timespec="seconds")
        save(d)
    elif cmd == "record-gsettings":
        key = f"{rest[0]} {rest[1]}"
        if key not in d["gsettings"]:
            d["gsettings"][key] = {"antes": rest[2]}
            save(d)
    elif cmd == "record-dconf":
        path = rest[0]
        if path not in d["dconf"]:
            d["dconf"][path] = {"antes": rest[1] if len(rest) > 1 else ""}
            save(d)
    elif cmd == "file-created":
        if rest[0] not in d["archivos_creados"]:
            d["archivos_creados"].append(rest[0])
            save(d)
    elif cmd == "file-removed":
        entry = {"ruta": rest[0], "symlink": rest[1] if len(rest) > 1 and rest[1] else None}
        if entry not in d["archivos_eliminados"]:
            d["archivos_eliminados"].append(entry)
            save(d)
    elif cmd == "ext-installed":
        if rest[0] not in d["extensiones_instaladas"]:
            d["extensiones_instaladas"].append(rest[0])
            save(d)
    elif cmd == "apt-installed":
        if rest[0] not in d["paquetes_apt"]:
            d["paquetes_apt"].append(rest[0])
            save(d)
    elif cmd == "dkms-installed":
        if rest[0] not in d["dkms"]:
            d["dkms"].append(rest[0])
            save(d)
    elif cmd == "system-file":
        entry = {"ruta": rest[0]}
        if entry not in d["sistema"]:
            d["sistema"].append(entry)
            save(d)
    elif cmd == "note":
        if rest[0] not in d["notas"]:
            d["notas"].append(rest[0])
            save(d)
    elif cmd == "has-note":
        return 0 if rest[0] in d["notas"] else 1
    elif cmd == "get":
        print(json.dumps(d.get(rest[0], {}), ensure_ascii=False))
    elif cmd == "dump":
        print(json.dumps(d, indent=2, ensure_ascii=False))
    else:
        print(f"orden desconocida: {cmd}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
