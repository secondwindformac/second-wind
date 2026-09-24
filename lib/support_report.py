"""support_report — the "Copy report for support" text (health plan, phase 1).

Builds a short, human-readable report from a CLOSED list of facts that can
be read WITHOUT an administrator password. Nothing is ever sent: the person
sees the whole text first and decides where to paste it.

Design rules (so a leak cannot slip in by accident):
  * every value is PARSED into a number or a known word — no raw command
    output, log line or file content is ever copied into the report;
  * logs are only COUNTED (last 7 days), never quoted;
  * a final guard (find_forbidden) rejects the report if it contains
    anything that looks like a user/host name, network name, serial, MAC or
    IP address, path or e-mail — belt and braces for the rules above.

All I/O goes through a Source object, so tests can feed simulated outputs
(with trap values) — see tests/test_support_report.py.
"""
import json
import os
import re
import subprocess
import time

DAYS = 7


class Source:
    """Real machine. Tests replace it with a fake that returns canned text."""

    def read(self, path):
        try:
            with open(path) as f:
                return f.read()
        except OSError:
            return None

    def run(self, cmd, timeout=6):
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
            return r.stdout if r.returncode == 0 else None
        except (OSError, subprocess.TimeoutExpired):
            return None

    def listdir(self, path):
        try:
            return sorted(os.listdir(path))
        except OSError:
            return []

    def now(self):
        return time.time()

    def private_words(self):
        """Values that must never appear: user, host, active network names."""
        words = set()
        try:
            import pwd
            u = pwd.getpwuid(os.getuid())
            words.add(u.pw_name)
            words.update(w for w in re.split(r"[ ,]+", u.pw_gecos or "") if len(w) > 2)
        except Exception:
            pass
        try:
            words.add(os.uname().nodename)
        except Exception:
            pass
        out = self.run(["nmcli", "-t", "-f", "NAME", "connection", "show", "--active"]) or ""
        words.update(l.strip() for l in out.splitlines() if l.strip() and l.strip() != "lo")
        return {w for w in words if len(w) >= 3}


# --- facts -------------------------------------------------------------------

def model(src, sw_root):
    ident = (src.read("/sys/class/dmi/id/product_name") or "").strip()
    names, anums, years = [], [], []
    try:
        rows = [r for r in json.loads(src.read(os.path.join(sw_root, "data", "macs.json")) or "{}")
                .get("models", []) if ident in r.get("identifiers", [])]
        names = sorted({r["name"] for r in rows})
        anums = sorted({a for r in rows for a in r["a_numbers"]})
        years = sorted({int(r["year"]) for r in rows})
    except (ValueError, KeyError, TypeError):
        pass
    # Only the shape of an Apple identifier / A-number / catalogue name passes.
    ident = ident if re.fullmatch(r"[A-Za-z]+\d+,\d+", ident) else ""
    anums = [a for a in anums if re.fullmatch(r"A\d{4}", a)]
    names = [n for n in names if re.fullmatch(r"[A-Za-z0-9 ()\-,.\"']{3,60}", n)]
    return {"ident": ident, "names": names, "anums": anums,
            "years": [y for y in years if 1990 < y < 2100]}


def versions(src, sw_root):
    sw = (src.read(os.path.join(sw_root, "VERSION")) or "").strip()
    sw = sw if re.fullmatch(r"\d+\.\d+(\.\d+)?", sw) else ""
    os_rel = src.read("/etc/os-release") or ""
    m = re.search(r'^VERSION="?(\d+\.\d+(?:\.\d+)?(?: LTS)?)', os_rel, re.M)
    return {"sw": sw, "ubuntu": m.group(1) if m else ""}


def memory(src):
    info = {}
    for line in (src.read("/proc/meminfo") or "").splitlines():
        m = re.match(r"(MemTotal|MemAvailable):\s+(\d+) kB", line)
        if m:
            info[m.group(1)] = int(m.group(2)) * 1024
    if "MemTotal" not in info or "MemAvailable" not in info:
        return None
    used = info["MemTotal"] - info["MemAvailable"]
    return {"total": info["MemTotal"], "used": max(used, 0)}


def disk(src):
    out = src.run(["df", "-B1", "--output=size,avail", "/"]) or ""
    nums = re.findall(r"^\s*(\d+)\s+(\d+)\s*$", out, re.M)
    if not nums:
        return None
    size, avail = map(int, nums[-1])
    return {"size": size, "free_pct": round(100 * avail / size) if size else 0}


def battery(src):
    base = "/sys/class/power_supply"
    for name in src.listdir(base):
        if not re.fullmatch(r"BAT\d", name):
            continue
        d = os.path.join(base, name)

        def num(f):
            v = (src.read(os.path.join(d, f)) or "").strip()
            return int(v) if v.isdigit() else None
        full = num("charge_full") or num("energy_full")
        design = num("charge_full_design") or num("energy_full_design")
        cycles = num("cycle_count")
        health = round(100 * full / design) if full and design else None
        return {"health": health, "cycles": cycles}
    return None


def wifi(src):
    loaded = None
    mods = src.read("/proc/modules")
    if mods is not None:
        loaded = any(l.split(" ", 1)[0] in ("wl", "brcmfmac", "brcmsmac", "b43", "iwlwifi", "ath9k")
                     for l in mods.splitlines())
    chip = ""
    base = "/sys/bus/pci/devices"
    for dev in src.listdir(base):
        d = os.path.join(base, dev)
        if (src.read(os.path.join(d, "class")) or "").strip() == "0x028000":
            v = (src.read(os.path.join(d, "vendor")) or "").strip().replace("0x", "")
            p = (src.read(os.path.join(d, "device")) or "").strip().replace("0x", "")
            if re.fullmatch(r"[0-9a-f]{4}", v) and re.fullmatch(r"[0-9a-f]{4}", p):
                chip = f"{v}:{p}"
                break
    return {"loaded": loaded, "chip": chip}


CHECK_KEYS = ("wifi", "sound", "camera", "keyboard_trackpad", "bluetooth", "battery")
CHECK_VALUES = ("ok", "ready", "missing", "pending", "na")


def mymac_checks(src, sw_root):
    out = src.run(["bash", os.path.join(sw_root, "bin", "second-wind-mymac"), "--json"],
                  timeout=10)
    try:
        d = json.loads(out or "")
    except ValueError:
        return None
    # Only the status words; the rest of that file is never used.
    return {k: d.get(k) for k in CHECK_KEYS if d.get(k) in CHECK_VALUES}


SHUTDOWN_MARKS = re.compile(r"Reached target (shutdown|reboot|poweroff|halt|kexec)\.target|"
                            r"systemd-shutdown|System is (rebooting|powering down|halting)")
# One OOM kill logs ~3 kernel lines ("invoked oom-killer", "oom-kill:", "Out of
# memory: Killed process"); count only the last one, once per kill.
OOM = re.compile(r"Out of memory: Killed process")
OOMD = re.compile(r"Killed .* due to memory (pressure|used)")
WIFI_DROP = re.compile(r"device \(wl[^)]*\): state change: activated -> "
                       r"(?:deactivating|disconnected|failed) \(reason '([a-z-]+)'")
# Not a drop: suspend, shutdown/reboot, the person switched it off.
WIFI_BENIGN = {"sleeping", "unmanaged", "user-requested", "removed", "connection-removed",
               "now-unmanaged", "device-removed"}


def counts(src):
    """Last 7 days. None when the journal is not readable without admin."""
    since = f"-{DAYS} days"
    res = {"crashes": None, "oom": None, "wifi_drops": None}
    boots = src.run(["journalctl", "--list-boots", "-o", "json", "--no-pager"])
    try:
        boots = json.loads(boots) if boots else None
    except ValueError:
        boots = None
    if isinstance(boots, list) and boots:
        limit = (src.now() - DAYS * 86400) * 1e6
        crashes = 0
        for b in boots:
            if b.get("index", 0) == 0 or b.get("last_entry", 0) < limit:
                continue    # the running boot, or older than 7 days
            tail = src.run(["journalctl", "-b", str(b["index"]), "-n", "400",
                            "-o", "cat", "--no-pager", "-q"]) or ""
            if not SHUTDOWN_MARKS.search(tail):
                crashes += 1
        res["crashes"] = crashes
    kern = src.run(["journalctl", "-k", "--since", since, "-o", "cat", "--no-pager", "-q"])
    oomd = src.run(["journalctl", "-u", "systemd-oomd", "--since", since,
                    "-o", "cat", "--no-pager", "-q"])
    if kern is not None:
        res["oom"] = sum(1 for l in kern.splitlines() if OOM.search(l)) + \
            sum(1 for l in (oomd or "").splitlines() if OOMD.search(l))
    nm = src.run(["journalctl", "-u", "NetworkManager", "--since", since,
                  "-o", "cat", "--no-pager", "-q"])
    if nm is not None:
        res["wifi_drops"] = sum(1 for l in nm.splitlines()
                                if (m := WIFI_DROP.search(l)) and m.group(1) not in WIFI_BENIGN)
    return res


def collect(src, sw_root):
    return {"model": model(src, sw_root), "versions": versions(src, sw_root),
            "memory": memory(src), "disk": disk(src), "battery": battery(src),
            "wifi": wifi(src), "checks": mymac_checks(src, sw_root), "counts": counts(src)}


# --- text ----------------------------------------------------------------------

T = {
    "title": ("Informe de Second Wind para soporte", "Second Wind support report"),
    "mac": ("Mac", "Mac"),
    "or": (" o ", " or "),
    "model_no": ("Número de modelo", "Model number"),
    "ident": ("Identificador", "Identifier"),
    "year": ("Año", "Year"),
    "sw": ("Second Wind", "Second Wind"),
    "ubuntu": ("Ubuntu", "Ubuntu"),
    "ram": ("Memoria", "Memory"),
    "ram_v": ("{t} en total · {u} en uso ({p} %)", "{t} total · {u} in use ({p} %)"),
    "disk": ("Disco", "Disk"),
    "disk_v": ("{t} en total · {f} % libre", "{t} total · {f} % free"),
    "bat": ("Batería", "Battery"),
    "bat_v": ("salud {h} · {c} ciclos", "health {h} · {c} cycles"),
    "wifi": ("WiFi", "WiFi"),
    "wifi_on": ("driver cargado", "driver loaded"),
    "wifi_off": ("sin driver cargado", "no driver loaded"),
    "chip": ("chip", "chip"),
    "checks": ("Revisión de Tu Mac", "Your Mac check"),
    "c_wifi": ("WiFi", "WiFi"), "c_sound": ("Sonido", "Sound"), "c_camera": ("Cámara", "Camera"),
    "c_keyboard_trackpad": ("Teclado y trackpad", "Keyboard and trackpad"),
    "c_bluetooth": ("Bluetooth", "Bluetooth"), "c_battery": ("Batería", "Battery"),
    "last7": ("Últimos 7 días", "Last 7 days"),
    "crashes": ("{n} cierres inesperados", "{n} unexpected shutdowns"),
    "oom": ("{n} veces sin memoria", "{n} out-of-memory events"),
    "drops": ("{n} desconexiones de WiFi", "{n} WiFi disconnections"),
    "na": ("no disponible", "not available"),
}
MARK = {"ok": "✔", "ready": "✔", "pending": "…", "missing": "✖"}


def _gb(n, es):
    g = n / 1024 ** 3
    s = f"{g:.0f} GB" if g >= 100 else f"{g:.1f} GB"
    return s.replace(".", ",") if es else s


def render(facts, lang="es"):
    es = lang.startswith("es")
    t = lambda k: T[k][0 if es else 1]
    na = t("na")
    L = [t("title"), ""]
    m = facts["model"]
    L.append(f"{t('mac')}: " + (t("or").join(m["names"]) or m["ident"] or na))
    ys = m["years"]
    year = (f"{ys[0]}" if len(ys) == 1 else f"{ys[0]}–{ys[-1]}") if ys else na
    L.append(f"{t('model_no')}: {', '.join(m['anums']) or na} · {t('ident')}: {m['ident'] or na} · "
             f"{t('year')}: {year}")
    v = facts["versions"]
    L.append(f"{t('sw')}: {v['sw'] or na}")
    L.append(f"{t('ubuntu')}: {v['ubuntu'] or na}")
    mem = facts["memory"]
    L.append(f"{t('ram')}: " + (t("ram_v").format(t=_gb(mem["total"], es), u=_gb(mem["used"], es),
                                                   p=round(100 * mem["used"] / mem["total"]))
                                 if mem else na))
    dk = facts["disk"]
    L.append(f"{t('disk')}: " + (t("disk_v").format(t=_gb(dk["size"], es), f=dk["free_pct"])
                                  if dk else na))
    b = facts["battery"]
    if b:
        L.append(f"{t('bat')}: " + t("bat_v").format(
            h=f"{b['health']} %" if b["health"] is not None else na,
            c=b["cycles"] if b["cycles"] is not None else na))
    w = facts["wifi"]
    state = na if w["loaded"] is None else t("wifi_on") if w["loaded"] else t("wifi_off")
    L.append(f"{t('wifi')}: {state} · {t('chip')} {w['chip'] or na}")
    c = facts["checks"]
    if c:
        L.append(f"{t('checks')}: " + " · ".join(
            f"{t('c_' + k)} {MARK[c[k]]}" for k in CHECK_KEYS if c.get(k) in MARK))
    else:
        L.append(f"{t('checks')}: {na}")
    n = facts["counts"]
    fmt = lambda k, v: t(k).format(n=v) if v is not None else f"{t(k).format(n='?')} ({na})"
    L.append(f"{t('last7')}: " + " · ".join([fmt("crashes", n["crashes"]), fmt("oom", n["oom"]),
                                            fmt("drops", n["wifi_drops"])]))
    return "\n".join(L) + "\n"


# --- guard ---------------------------------------------------------------------

FORBIDDEN = [
    ("MAC address", re.compile(r"\b[0-9A-Fa-f]{2}(?:[:-][0-9A-Fa-f]{2}){5}\b")),
    ("IPv4 address", re.compile(r"\b\d{1,3}(?:\.\d{1,3}){3}\b")),
    ("IPv6 address", re.compile(r"\b[0-9A-Fa-f]{1,4}(?::[0-9A-Fa-f]{0,4}){2,7}\b")),
    ("path", re.compile(r"(?:^|[\s(])(?:~|\.{0,2})/[\w.\-]")),
    ("e-mail", re.compile(r"[\w.+-]+@[\w-]+\.[\w.]+")),
    ("serial number", re.compile(r"\b(?=[A-Z0-9]*\d)(?=[A-Z0-9]*[A-Z])[A-Z0-9]{10,14}\b")),
]


def _fixed_vocabulary():
    """Words the report is built from (labels, units): a private word equal to
    one of them cannot be told apart and carries no information — e.g. the
    Air's account full name is "Second Wind" (set by the installer)."""
    words = set()
    for es, en in T.values():
        words.update(re.findall(r"[\w-]+", es + " " + en))
    words.update(("Mac", "MacBook", "Air", "Pro", "Mini", "iMac", "inch", "Early", "Mid", "Late"))
    return {w.lower() for w in words}


def find_forbidden(text, private_words=()):
    """Names of what leaked (empty = clean). Private words (user, full name,
    host, network) match whole words, case-sensitively; words that are part of
    the report's own fixed vocabulary are skipped (see _fixed_vocabulary)."""
    hits = [name for name, rx in FORBIDDEN if rx.search(text)]
    fixed = _fixed_vocabulary()
    for w in private_words:
        if w.lower() in fixed:
            continue
        if re.search(r"(?<![\w-])" + re.escape(w) + r"(?![\w-])", text):
            hits.append("private name")
            break
    return hits


def build(src=None, sw_root=None, lang=None):
    """(text, problems). If problems is non-empty the text must NOT be shown."""
    src = src or Source()
    sw_root = sw_root or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    lang = lang or os.environ.get("LANG", "en")
    text = render(collect(src, sw_root), lang)
    return text, find_forbidden(text, src.private_words())
